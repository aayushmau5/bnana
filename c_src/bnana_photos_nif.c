#include <erl_nif.h>

extern void bnana_present_photo_picker(ErlNifPid pid);

static ERL_NIF_TERM pick(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    (void)argv;

    ErlNifPid pid;
    enif_self(env, &pid);
    bnana_present_photo_picker(pid);
    return enif_make_atom(env, "ok");
}

static ErlNifFunc nif_funcs[] = {
    {"pick", 0, pick, 0},
};

ERL_NIF_INIT(bnana_photos_nif, nif_funcs, NULL, NULL, NULL, NULL)
