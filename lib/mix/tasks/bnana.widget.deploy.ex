defmodule Mix.Tasks.Bnana.Widget.Deploy do
  @moduledoc false

  use Mix.Task

  @shortdoc "Builds and deploys bnana with its iOS widget"

  @app_name "Bnana"
  @app_bundle_id "com.aayushmau5.bnana"
  @extension_name "BnanaAnalyticsWidget"
  @extension_bundle_id "com.aayushmau5.bnana.widget"
  @compile {:no_warn_undefined, MobDev.Config}
  @compile {:no_warn_undefined, MobDev.NativeBuild}
  @compile {:no_warn_undefined, MobDev.Release}

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: [device: :string, restart: :boolean])
    device_id = opts[:device] || MobDev.NativeBuild.detect_physical_ios()
    if is_nil(device_id), do: Mix.raise("Connect an iPhone or pass --device <UDID>")
    deploy_args = if opts[:device], do: args, else: ["--device", device_id | args]

    ensure_widget_profile!()
    repair_mob_cache_permissions!()
    Mix.Task.run("mob.deploy", ["--native", "--ios" | deploy_args])

    with_built_extension!(fn extension_path ->
      app_path = latest_mob_app!()
      sync_bundle_versions!(app_path, extension_path)

      plugins_path = Path.join(app_path, "PlugIns")
      embedded_extension = Path.join(plugins_path, Path.basename(extension_path))
      File.mkdir_p!(plugins_path)
      File.rm_rf!(embedded_extension)
      File.cp_r!(extension_path, embedded_extension)

      sign!(app_path, embedded_extension)
      install!(app_path, device_id, Keyword.get(opts, :restart, true))
    end)

    Mix.shell().info("\nBnana and its widgets are installed.")
  end

  defp latest_mob_app! do
    System.tmp_dir!()
    |> Path.join("mob_ios_device_*/#{@app_name}.app")
    |> Path.wildcard()
    |> Enum.map(fn path -> {path, File.stat!(path).mtime} end)
    |> Enum.max_by(&elem(&1, 1), fn ->
      Mix.raise("Mob completed without producing an iOS app bundle")
    end)
    |> elem(0)
  end

  defp with_built_extension!(callback) do
    build_dir =
      Path.join(System.tmp_dir!(), "bnana_widget_#{System.unique_integer([:positive])}")

    try do
      command!("xcodebuild", [
        "-project",
        "ios/Provision.xcodeproj",
        "-target",
        @extension_name,
        "-configuration",
        "Debug",
        "-sdk",
        "iphoneos",
        "SYMROOT=#{Path.join(build_dir, "Build/Products")}",
        "OBJROOT=#{Path.join(build_dir, "Build/Intermediates.noindex")}",
        "CODE_SIGNING_ALLOWED=NO",
        "CODE_SIGNING_REQUIRED=NO",
        "build"
      ])

      callback.(Path.join(build_dir, "Build/Products/Debug-iphoneos/#{@extension_name}.appex"))
    after
      File.rm_rf(build_dir)
    end
  end

  defp sync_bundle_versions!(app_path, extension_path) do
    app_info = Path.join(app_path, "Info.plist")
    extension_info = Path.join(extension_path, "Info.plist")

    for key <- ~w(CFBundleShortVersionString CFBundleVersion) do
      value =
        command!("/usr/libexec/PlistBuddy", ["-c", "Print :#{key}", app_info])
        |> String.trim()

      command!("/usr/libexec/PlistBuddy", [
        "-c",
        "Set :#{key} #{value}",
        extension_info
      ])
    end
  end

  defp sign!(app_path, extension_path) do
    profile = widget_profile!()
    identity = signing_identity!()
    extension_profile_path = profile.path
    File.cp!(extension_profile_path, Path.join(extension_path, "embedded.mobileprovision"))

    app_profile_path = Path.join(app_path, "embedded.mobileprovision")

    signing_dir =
      Path.join(System.tmp_dir!(), "bnana_signing_#{System.unique_integer([:positive])}")

    File.mkdir_p!(signing_dir)

    try do
      extension_entitlements =
        profile_entitlements!(extension_profile_path, "widget", signing_dir)

      app_entitlements = profile_entitlements!(app_profile_path, "app", signing_dir)

      codesign!(extension_path, identity, extension_entitlements)
      codesign!(app_path, identity, app_entitlements)
      verify_signature!(app_path)
    after
      File.rm_rf(signing_dir)
    end
  end

  defp widget_profile! do
    configured_uuid = mob_config()[:ios_widget_profile_uuid]
    matches = widget_profiles(configured_uuid)

    case matches do
      [profile] ->
        profile

      [] ->
        Mix.raise("""
        No iOS Development provisioning profile was found for #{@extension_bundle_id}.
        Add that App ID and #{@app_bundle_id} to the App Group group.com.aayushmau5.bnana,
        create Development profiles for both, then download them in Xcode.
        """)

      _many ->
        Mix.raise("""
        Multiple widget profiles were found. Add this to mob.exs with the profile to use:
        config :mob_dev, ios_widget_profile_uuid: "PROFILE-UUID"
        """)
    end
  end

  defp ensure_widget_profile! do
    if widget_profiles(nil) == [] do
      build_dir =
        Path.join(System.tmp_dir!(), "bnana_provision_#{System.unique_integer([:positive])}")

      Mix.shell().info("Creating the widget App ID and Development profiles with Xcode...")

      try do
        command!("xcodebuild", [
          "-project",
          "ios/Provision.xcodeproj",
          "-target",
          "MobProvision",
          "-configuration",
          "Debug",
          "-sdk",
          "iphoneos",
          "SYMROOT=#{Path.join(build_dir, "Build/Products")}",
          "OBJROOT=#{Path.join(build_dir, "Build/Intermediates.noindex")}",
          "-allowProvisioningUpdates",
          "build"
        ])
      after
        File.rm_rf(build_dir)
      end
    end
  end

  defp widget_profiles(configured_uuid) do
    provisioning_profile_paths()
    |> Enum.flat_map(fn path ->
      MobDev.Release.parse_mobileprovision(path)
      |> Enum.map(&Map.put(&1, :path, path))
    end)
    |> Enum.filter(fn profile ->
      profile.provisioned_devices? and
        String.ends_with?(profile.app_id, ".#{@extension_bundle_id}") and
        (is_nil(configured_uuid) or profile.uuid == configured_uuid)
    end)
  end

  defp provisioning_profile_paths do
    [
      Path.expand("~/Library/Developer/Xcode/UserData/Provisioning Profiles/*.mobileprovision"),
      Path.expand("~/Library/MobileDevice/Provisioning Profiles/*.mobileprovision")
    ]
    |> Enum.flat_map(&Path.wildcard/1)
  end

  defp repair_mob_cache_permissions! do
    Path.expand("~/.mob/cache/otp-ios-device-*")
    |> Path.wildcard()
    |> Enum.each(&command!("chmod", ["-R", "u+w", &1]))
  end

  defp profile_entitlements!(profile_path, label, directory) do
    decoded = Path.join(directory, "#{label}_profile.plist")
    entitlements = Path.join(directory, "#{label}_entitlements.plist")

    command!("security", ["cms", "-D", "-i", profile_path, "-o", decoded])
    command!("plutil", ["-extract", "Entitlements", "xml1", "-o", entitlements, decoded])

    case command("/usr/libexec/PlistBuddy", [
           "-c",
           "Print :com.apple.security.application-groups",
           entitlements
         ]) do
      {groups, 0} when is_binary(groups) ->
        if String.contains?(groups, "group.com.aayushmau5.bnana") do
          entitlements
        else
          missing_app_group!(label)
        end

      _ ->
        missing_app_group!(label)
    end
  end

  defp missing_app_group!(label) do
    Mix.raise("The #{label} provisioning profile does not include group.com.aayushmau5.bnana")
  end

  defp signing_identity! do
    case mob_config()[:ios_sign_identity] do
      identity when is_binary(identity) ->
        identity

      nil ->
        {output, 0} = command("security", ["find-identity", "-v", "-p", "codesigning"])

        identities =
          Regex.scan(~r/\d+\) [0-9A-F]+ "([^"]*Apple Development[^"]*)"/, output)
          |> Enum.map(fn [_, identity] -> identity end)
          |> Enum.uniq()

        case identities do
          [identity] ->
            identity

          [] ->
            Mix.raise("No Apple Development signing identity was found")

          _many ->
            Mix.raise("Multiple signing identities found; set ios_sign_identity in mob.exs")
        end
    end
  end

  defp codesign!(path, identity, entitlements) do
    command!("codesign", [
      "--force",
      "--sign",
      identity,
      "--entitlements",
      entitlements,
      "--timestamp=none",
      "--generate-entitlement-der",
      path
    ])
  end

  defp verify_signature!(app_path) do
    command!("codesign", ["--verify", "--deep", "--strict", "--verbose=2", app_path])
  end

  defp install!(app_path, device_id, restart?) do
    command!("xcrun", ["devicectl", "device", "install", "app", "--device", device_id, app_path])

    if restart? do
      command!("xcrun", [
        "devicectl",
        "device",
        "process",
        "launch",
        "--terminate-existing",
        "--device",
        device_id,
        @app_bundle_id
      ])
    end
  end

  defp command!(executable, args) do
    case command(executable, args) do
      {output, 0} -> output
      {output, status} -> Mix.raise("#{executable} failed (#{status}):\n#{output}")
    end
  end

  defp command(executable, args) do
    System.cmd(executable, args, stderr_to_stdout: true)
  end

  defp mob_config do
    MobDev.Config.load_mob_config()
  end
end
