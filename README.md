# nova-sl7-novat2k

Dockerfile for the packaging the jointfit_novat2k repository and various glue
code into a container providing the NOvA likelihood evaluation for the nova/t2k
joint fit.

# Instructions for building docker image locally

You may also use podman by simply replacing "docker" with "podman" throughout.

    # Clone this repository
    git clone git@github.com:novaexperiment/nova-sl7-novat2k.git
    cd nova-sl7-novat2k

    # Fetch the fitting code which we are packaging, among other things
    git clone -b feature/nudock_2024Ana --recurse-submodules git@github.com:novaexperiment/jointfit_novat2k

    # Build container using the default Dockerfile
    # If you are trying to pick up an updated external repository you may need --no-cache
    docker build -t ghcr.io/novaexperiment/nova-sl7-novat2k .

    # Upload the resulting image to dockerhub
    docker login ghcr.io
    docker push ghcr.io/novaexperiment/nova-sl7-novat2k:latest
    docker logout

To create a .sif file without going via dockerhub:

    docker save <image_id> -o img.tar
    singularity build img.sif img.tar

# Quicl local run & test
For a quick run locally:

```bash
# Fetch everything
git clone git@github.com:novaexperiment/nova-sl7-novat2k.git
cd nova-sl7-novat2k
git clone --recurse-submodules git@github.com:novaexperiment/jointfit_novat2k

# Build container & a writable image
docker build --no-cache -t novat1k_test .
singularity build --sandbox image.sif docker-daemon://novat2k_test:latest
```

The created `image.sif` will be a folder that you can easily edit if needed (swap out the schemas, recompile the software etc).

You can run test by starting the server:

```bash
./run_container.sh
```

And the client:

```bash
./run_client.sh
```

to enter the container environment (can be useful if you want to e.g. rebuild software for tests):

```bash
singularity shell --writable image.sif
```

# Server endpoints

The server (`jointfit_novat2k/CAFAna/run.C`) registers five JSON-over-HTTP
endpoints (schemas in `/nova/jointfit_novat2k/include/nudock/schemas` unless
noted):

| Endpoint | Request | Response |
|----------|---------|----------|
| `/ping` | string | `"pong"` |
| `/set_parameters` | `{osc_pars: {...}, sys_pars: {...}}` (NSI keys optional, see below) | status object |
| `/log_likelihood` | string (ignored) | `{log_likelihood, duration_us}` |
| `/get_parameter_names` | string (ignored) | `{osc_pars: [...], sys_pars: [...]}` |
| `/set_asimov_point` | string: `"asimov"` (or empty), `"poisson"`, `"reset"` | status string |

`/set_asimov_point` generates Asimov fake data **on the fly** — the in-server
equivalent of a `make_fakedata.C` output file, without restarting the server.
The client first sends the desired Asimov point via `/set_parameters`; calling
`/set_asimov_point` then snapshots those parameters, and the data spectra are
regenerated from them (prediction + cosmics, at the original data POT /
livetime) at the next `/log_likelihood` evaluation. Modes:

- `"asimov"` (or `""`): Asimov data at the snapshotted parameters
- `"poisson"`: same, plus Poisson fluctuations (mock data; unseeded, differs every time)
- `"reset"`: restore the original data loaded from `/jf_data`

Its schema is not yet in NuDock main, so it ships in this package
(`jointfit_novat2k/CAFAna/schemas/set_asimov_point.schema.json`, identical to
the one on NuDock's `mach3_branch`) and is registered with an explicit path.

## Non-standard interactions (NSI)

The server oscillates with `OscCalcPMNS_NSI` (OscLib), wrapped as
`OscCalcPMNS_NSIHashed` (`jointfit_novat2k/CAFAna/Experiment/`) so that
CAFAna's oscillated-spectrum caches also key on the NSI parameters. Besides the
six standard parameters, `osc_pars` accepts nine **optional** NSI keys, all
defaulting to 0 (standard three-flavour oscillations, bit-identical to the
previous `OscCalcPMNSOpt` server):

| Key | Meaning |
|-----|---------|
| `Eps_ee`, `Eps_mumu`, `Eps_tautau` | real diagonal ε |
| `Eps_emu`, `Eps_etau`, `Eps_mutau` | modulus of the off-diagonal ε |
| `Delta_emu`, `Delta_etau`, `Delta_mutau` | phase of the off-diagonal ε (radians) |

Every NSI key is reset to 0 on each `/set_parameters` call that omits it, so
clients that never send them are unaffected. `/set_asimov_point` snapshots the
NSI values too, so NSI Asimov data can be generated on the fly. The NSI-aware
`set_parameters` schema (NuDock's own rejects unknown `osc_pars` keys) ships in
`jointfit_novat2k/CAFAna/schemas/set_parameters.schema.json` and is registered
with an explicit path, like `set_asimov_point`.

Test against a running Docker server with `./run_test_nsi_docker.sh` (expect
`ALL CHECKS PASSED`).

