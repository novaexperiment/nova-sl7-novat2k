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
    # (--recurse-submodules also fetches its extern/OscLib and extern/nudock-schemas)
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

The server (`jointfit_novat2k/CAFAna/run.C`) registers seven JSON-over-HTTP
endpoints (schemas: see [Schemas](#schemas) below):

| Endpoint | Request | Response |
|----------|---------|----------|
| `/ping` | string | `"pong"` |
| `/set_parameters` | `{osc_pars: {...}, sys_pars: {...}}` (NSI keys optional, see below) | status object |
| `/log_likelihood` | string (ignored) | `{log_likelihood, duration_us}` |
| `/get_parameter_names` | string (ignored) | `{osc_pars: [...], sys_pars: [...]}` |
| `/set_asimov_point` | string: `"asimov"` (or empty), `"poisson"`, `"reset"` | status string |
| `/get_data_spectrum` | string (ignored) | data spectrum of every sample, see [Spectra](#spectra) |
| `/get_mc_spectrum` | string (ignored) | expected spectrum of every sample at the current parameters, see [Spectra](#spectra) |

Systematic shifts not listed in a `/set_parameters` request keep their previous
value (unlike the NSI parameters, which are reset to 0).

`/set_asimov_point` generates Asimov fake data **on the fly** — the in-server
equivalent of a `make_fakedata.C` output file, without restarting the server.
The client first sends the desired Asimov point via `/set_parameters`; calling
`/set_asimov_point` then snapshots those parameters, and the data spectra are
regenerated from them (prediction + cosmics, at the original data POT /
livetime) at the next `/log_likelihood` (or `/get_data_spectrum`) call. Modes:

- `"asimov"` (or `""`): Asimov data at the snapshotted parameters
- `"poisson"`: same, plus Poisson fluctuations (mock data; unseeded, differs every time)
- `"reset"`: restore the original data loaded from `/jf_data`

## Spectra

`/get_data_spectrum` and `/get_mc_spectrum` return, for every sample, the two
spectra the likelihood compares:

- data: the loaded data file, or the Asimov/mock data after `/set_asimov_point`
- MC: the expectation at the current `/set_parameters` point, i.e. the
  (systematically shifted) beam prediction plus cosmics, at the data exposure

so the χ² can be recomputed from them bin by bin (CAFAna's Poisson likelihood,
`LogLikelihood()` in `CAFAna/Core/Utilities.cxx`). The request string is not
used yet (all samples are returned). The reply follows the shared schema:
`sample_names`, plus per sample `dimensions` (always 1 for NOvA),
`axis_titles`, `bin_edges` (a single edge list) and `bin_values` (one value per
bin, no under/overflow).

| Samples | Bins |
|---------|------|
| `numu_fhc_1`..`numu_fhc_4`, `numu_rhc_1`..`numu_rhc_4` | 22 bins of reconstructed neutrino energy, 0–5 GeV, variable width |
| `nueLowE_fhc` | 4 bins of reconstructed nue energy, 0–2 GeV |
| `nue_fhc`, `nue_rhc` | 23 analysis bins, see below |

The `nue_fhc`/`nue_rhc` axis is NOvA's flattened analysis-bin index (it
matches `kNue2024AxisMergedPeripheral` in novasoft's
`3FlavorAna/Cuts/NueCuts2024.cxx`): bin = 9 × class + ⌊E / 0.5 GeV⌋, with
class 0 = low-CVN core and 1 = high-CVN core, and all peripheral events in
bin 20.

| Bins | Content |
|------|---------|
| 0–8 | low-CVN core, reconstructed energy 0–4.5 GeV in 0.5 GeV steps |
| 9–17 | high-CVN core, same energy steps |
| 20 | peripheral |
| 18, 19, 21, 22 | always empty |

In the current input files only bins 2–7, 11–16 (core, 1–4 GeV) and 20 are
non-empty. Whether to expose these samples as 2D (energy × CVN class) instead
is an open question for the shared schema.

Test against a running Docker server with `./run_test_spectra_docker.sh`
(expect `ALL CHECKS PASSED`).

## Schemas

The request/response schemas are the common NOvA-T2K ones from
[nova-t2k/nudock-schemas](https://github.com/nova-t2k/nudock-schemas), checked
out as the `extern/nudock-schemas` git submodule of `jointfit_novat2k`. They are
therefore pinned to the commit recorded there, and baked into the image at
`/nova/jointfit_novat2k/extern/nudock-schemas/schemas`. NuDock's own bundled
schemas (`/nova/jointfit_novat2k/include/nudock/schemas`) are not used.

The server validates every request and response against them; a validation
failure makes NuDock reply with HTTP 400 **and stop the server**. The schemas
repo also defines `get_parameters` (optional), which this server does not
implement yet. `get_data_spectrum` / `get_mc_spectrum` are implemented against
the current versions of their schemas, which are still marked "to be
confirmed".

To move to a newer version of the schemas:

    git -C jointfit_novat2k/extern/nudock-schemas fetch
    git -C jointfit_novat2k/extern/nudock-schemas checkout <commit or tag>
    # rebuild the image, run the tests, then record the new pointer
    git -C jointfit_novat2k add extern/nudock-schemas

To try out schema changes without rebuilding, point the server at another
directory with `NUDOCK_SCHEMAS_DIR` (a path inside the container). With
`run_container_docker.sh` it is instead a host directory, which the script
mounts into the container:

    NUDOCK_SCHEMAS_DIR=../nudock-schemas/schemas ./run_container_docker.sh

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
NSI values too, so NSI Asimov data can be generated on the fly.

The shared `set_parameters` schema requires the six standard parameters but
accepts any other numeric `osc_pars` key, so it does not catch a mistyped NSI
key. The server ignores `osc_pars` and `sys_pars` keys it does not use
(`/get_parameter_names` lists the ones it does), lists them in every reply's
status, and prints a warning in its log (once per key for `osc_pars`):

    {"status": "Parameters set with warnings: ignored osc_pars [Eps_mumuu]; ignored sys_pars [not_a_syst]"}

Without ignored keys the status is `"Parameters set successfully"`. The status
is free-form text because the shared schema allows no other reply fields.

Test against a running Docker server with `./run_test_nsi_docker.sh` (expect
`ALL CHECKS PASSED`).

