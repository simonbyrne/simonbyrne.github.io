# HPC tooling is terrible


https://twitter.com/danielskatz/status/1498293078020571143


For the past 3 years I've been working on the [CliMA project](https://clima.caltech.edu/), which has meant that I've needed to re-aquaint myself with the world that calls itself _high-peformance computing_ (HPC). There are lots of interesting and exciting things in this domain, not to mention fantastic and brilliant people. However the tooling and usability of the systems and software is attrocious, which makes it difficult for both developers and users of HPC software.


# What is a HPC system, and how are they used?

A HPC system can range from a small cluster run by a single research group, to a [half-billion dollar supercomputer](https://en.wikipedia.org/wiki/Frontier_(supercomputer)), but (very) roughly speaking it will consist of:

- a number of _compute nodes_, which do the actual work. They may include attached accelerators such as GPUs.
- a low-latency, high-throughput network, such as [InfiniBand](https://en.wikipedia.org/wiki/InfiniBand): these often support features like [remote direct memory access](https://en.wikipedia.org/wiki/Remote_direct_memory_access).
- a parallel file system, such as [Lustre](https://en.wikipedia.org/wiki/Lustre_(file_system)) for storage and I/O.
- a batch scheduling system, such as [Slurm](https://en.wikipedia.org/wiki/Slurm_Workload_Manager), which allocates the resources to a particular job.

A user will typically interact with the system as follows:

1. SSH to a _login node_: this is a fairly standard multi-user linux system, intended for light administrative tasks.
2. Copy data and/or code from outside to the parallel file system.
3. Set up the _submission script_: this is a shell script which will be executed on the compute nodes
4. Submit the script to the scheduler, along with the required resources (number of cores, memory, GPUs, and length of time).

The scheduler will then add the job to its queue: when the resources are available it will start the job on the compute nodes. This is usually set up in a way so that the environment on the compute nodes mimics that of the login node as much as possible: drives are mounted in the same locations, and the environment variables on the login node are replicated in the environment on the compute nodes.

That sounds simple enough, and indeed most scientists with some basic command line knowledge are able to get up and running reasonably quickly, or perhaps more likely, they are able to adapt a sample script they received from a colleague to their own needs.

# What is so bad about HPC systems?

Now consider a couple of questions that someone using this system might have.

### How do I check a running job?

So lets start with the first thing our user would want to know after submission: how is my job going?

To see what the job is doing, the process is typically:

1. SSH back into the login node: two-factor authentication is starting to get annoying.
2. Query the job status to see if it's still running: what's the command again? Was it `sinfo`? Ah, no, it was `squeue`. That's a lot of jobs: how do I find the one I just started?
3. Find the file containing stdout redirection: ah, there's a bunch of them. I need to find the job number!
4. Open it or write it to my terminal.

Now, I could have configured my job so that it will sent me an email when it started or finished, but compared with the nice web dashboards and live rendering of logs provided by  CI services such as GitHub Actions and Buildkite, this is basically the stone age.

### What did I run?

Now suppose we need to make some modifications to our job, say use a different value to a command line flag in their code, but everything else is the same. A quick edit to their submission script to reflect their changes, and submit it again to the scheduler. That was easy!

Oh, that was the wrong dataset, just change the path and submit it again.

Ah, they need to modify a parameter value: edit the script and submit again.

and so on.

Fast-forward to a few months later when it is time to write up the results: how can I match the inputs and results: I _think_ I used these parameters for this job? Oh, which dataset did I use?

Cluster submission systems fundamentally discourage good practices of keeping track of job inputs and linking them with the resulting outputs. Sure, the user _could_ have stored their submission scripts in separarate directories or tracked them with version control, but this takes considerable extra effort and diligence from the user, and there is no guarantee that they don't mess up and accidentally overwrite the results of one experiment with another.

### What was my environment?

As with any system, users will typically start to customize their profiles and add extra software: though they typically won't have root access, they can build programs in their home directory, and the cluster may provide [environment modules](https://www.admin-magazine.com/HPC/Articles/Environment-Modules) to make multiple versions of software available, which users might add to their `.profile`, e.g. so they can get a version of git that is less than a decade old.

For convenience, the cluster submission system will also helpfully copy the users environment to the compute nodes, so any modules that have been loaded at submission will also be loaded as part of the job.

While convenient it does make reproducibility more difficult: our user can't just share their submission script with another user, as it may depend on the particular

### How do I run my MPI program?

For better or worse, [MPI (Message Passing
Interface)](https://en.wikipedia.org/wiki/Message_Passing_Interface) is the
lingua franca of parallelism in HPC. There are many valid criticisms of the MPI
standard (see for example, [Jonathon Dursi's
posts](https://www.dursi.ca/tag#MPI)), but overall its
[SPMD](https://en.wikipedia.org/wiki/SPMD) model has proven fairly successful
and adaptable for many scientific problems.

MPI is just a standard specifed by the [MPI Forum](https://www.mpi-forum.org/), of which
there are multiple implementations: there are two large open source implementations (MPICH
and Open MPI), as well as many derivative implementations, most of these are by companies
(HPE-Cray, IBM, Fujitsu, Intel, Microsoft) targetting their own specific platforms.

Although the function signatures are the same, the ABI (application binary
interface, which specifies things like struct layouts, symbols and enum values)
can be different between implementations. Functionality can also differ, for
example some "GPU-aware" implementations allow passing GPU pointers directly
into MPI functions, avoiding the need to first copy the data to the host.
Overall this means that code built against one MPI implementation will probably
not work with another.

However by far the most frustrating thing about MPI is simply launching MPI programs. In
practice, this is done via a launcher executable which spawns the necessary processes on
the relevant nodes, and sets up the necessary network connections between them. This
requires tight integration with the cluster (e.g. so that the launcher knows on which
nodes to launch processes, and what networking hardware to use).

Unfortunately, this is completely non-standard: in some cases it is done via a program
provided by the MPI implementation (called `mpiexec` or `mpirun`), in other cases it is
done via the cluster scheduler (`srun` on Slurm, `aprun` on PBS). These launchers take a
plethora of options, specifying different processor layouts, networking options, handling
of input and output, which are not at all consistent between implementations.

All of this makes it exceptionally hard to build MPI into larger pieces of software, for
example providing an interactive front-end to an MPI program. If you want to use MPI with an interactive REPL in a language like Julia or Python, the current state-of-the-art approach is to
[run it inside a tmux window](https://github.com/Azrael3000/tmpi).

This also makes using containers difficult: as the launcher itself needs to
interact with the cluster scheduler, it can't live inside the container. Instead, the
recomended approach is that [the launcher starts the
container](https://apptainer.org/docs/user/1.0/mpi.html). This means that your
application inside the container still has to be built against the particular
MPI on the system (partly defeating the purpose of using a container).
Additionally any non-MPI components (e.g. preprocessing steps, or a web
front-end) now need to live outside the MPI container process, which further
limits portability and reproducibility.

### How can I incorporate HPC into my workflow?

Ultimately, however, the biggest problem is that HPC tools make it exceptionally difficult to adapt them into larger workflows.

[Matt Segal has an excellent post](https://mattsegal.dev/devops-academic-research.html) describing his development of an automated modeling workflow for an epidemiology research group: one of the first things he did was give up on using the Slurm cluster and switched to using cloud resources instead. He expands a bit more on the issues in a [Twitter thread](https://twitter.com/mattdsegal/status/1462959078381002752), but ultimately the HPC system couldn't be made to work in a way that fit his workflow.

There are an increasing number of tools that have been developed to manage complicated workflows and pipelines: some like Snakemake and Nextflow have their roots in the bioinformatics world, and so have some limited support for HPC systems, though they often expect you [to run it from the login node](https://www.nextflow.io/docs/latest/executor.html#slurm), which limits the ability to interact with other systems (e.g. cloud services). Others, such as [Apache Airflow](https://airflow.apache.org/) come from the data science world: these tools often provide nice GUI frontends, but are much less compatible with HPC systems, and efforts to integrate them are [adhoc at best](https://avik-datta-15.medium.com/how-to-setup-apache-airflow-on-hpc-cluster-ea2575764b43).


# How to improve things?

It's easy to complain, so here are a couple of concrete suggestions that could improve usability of HPC systems.

## Web-based dashboard and logs

I should be able to see the status of my jobs and their live logs from a website. The cluster manager could either provide a simple web server to host these, or provide integration with third-party services such as Buildkite.

## Provide REST web APIs and hooks

It should be possible to trigger cluster functions (job submission, querying status) via standard web APIs. This would allow integrating HPC systems with cloud services, and form the basis on which other services could be built. I should be able to trigger a job from a GitHub webhook, and have it update the status once complete.

## Sandboxed environments

Compute environments should move away from trying to emulate the users account
on the login node to being a fully sandboxed, reproducible environment. A job
specification should declaratively describe both the required resources, as well
as the environment in which it is run (loaded software, mounted directories,
etc), and be fully transferrable between users. I should be able to launch MPI
jobs from within the sandbox.

This would also enable much more flexible permissions: rather than a job
belonging to a single user, it could belong to a group or account and be freely
modifiable by anyone with the relevant permissions. A lot of these ideas already
exist in cloud tooling and deployment systems like Kubernetes: these approaches
have proven very successful in other domains and the HPC world needs to embrace
these.

There have been efforts to [better support
containers](https://slurm.schedmd.com/containers.html#types), but many of these
are one-off efforts targetted at a particular center or system.

## Security

Whenever I have discussed these ideas with people in the area, the inevitable obstacle
that gets mentioned is security. This is not an idle concern: in 2020 several European
computing centers were [hit by a cyberattacks](https://www.datacenterdynamics.com/en/news/european-supercomputers-hacked-mine-cryptocurrency/),
and many "open compute" services such as [BinderHub have been targetted by crypto miners](https://github.com/pangeo-data/pangeo-binder/issues/195).

I'm not a cybersecurity expert, but it does seem that if HPC centers want to
provide more useful services to their users, they need to completely rethink
their approach to security. My former colleague Keno Fisher points out that this
has to [start with the hardware](https://twitter.com/KenoFischer/status/1260661149017665536), but the
software also needs a radical rethink. The Unix permissions model of users and
groups is too inflexible, and not at all amenable to collaborative workflows.
For example [Jacamar CI](https://gitlab.com/ecp-ci/jacamar-ci), a valiant effort
to provide CI services on HPC systems, has to jump through a lot of hoops to
provide a coherent security model, and even then is limited to users who have existing
accounts on the HPC system.
