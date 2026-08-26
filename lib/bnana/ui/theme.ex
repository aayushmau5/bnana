defmodule Bnana.Theme do
  @moduledoc "Vitesse Dark-inspired design tokens for Bnana."

  @doc "Returns Bnana's application theme."
  @spec theme() :: Mob.Theme.t()
  def theme do
    Mob.Theme.build(
      primary: 0xFF4D9375,
      on_primary: 0xFF121212,
      secondary: 0xFFE6CC77,
      on_secondary: 0xFF121212,
      background: 0xFF121212,
      on_background: 0xFFDBD7CA,
      surface: 0xFF181818,
      surface_raised: 0xFF202020,
      on_surface: 0xFFDBD7CA,
      muted: 0xFF95938C,
      error: 0xFFCB7676,
      on_error: 0xFF121212,
      border: 0xFF2F363D,
      radius_sm: 6,
      radius_md: 10,
      radius_lg: 16,
      radius_pill: 100,
      type_scale: 1.0,
      space_scale: 1.0,
      glass: false
    )
  end
end
