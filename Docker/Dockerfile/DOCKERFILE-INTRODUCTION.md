# Dockerfile essentials

The examples use the Go app in [`./app`](./app/main.go) and different Dockerfiles to show how instructions affect the final image.


# Common Dockerfile instructions

- `FROM` selects the base image and starts a build stage.
- `ARG` defines a build-time variable. It is the only instruction allowed before the first `FROM`. Also worth mentioning that it's scopped.
- `RUN` executes a command while building the image and saves the filesystem changes.
- `COPY` copies files from the build context or another stage into the image.
- `ADD` also copies files, and can fetch a URL or unpack a local tar archive. A tar archive fetched from a URL is not unpacked automatically.
- `ENV` sets an environment variable that remains available in the built image and its containers.
- `WORKDIR` sets the directory for later instructions and the container's starting working directory.
- `CMD` sets the default command or default arguments for `ENTRYPOINT`. `docker run` arguments can replace it; only the last `CMD` takes effect.
- `ENTRYPOINT` sets the executable run when the container starts. With exec-form `ENTRYPOINT`, `CMD` can supply its default arguments.



## Build arguments

Build arguments are variables for the Dockerfile itself. Use them to parameterize values of Dockerfile instructions.
In Docker Build, build arguments (ARG) and environment variables (ENV) both serve as a means to pass information into the build process. You can use them to parameterize the build, allowing for more flexible and configurable builds.

Example [`Dockerfile`](./arg):
```shell
docker build --build-arg NAME=paulao -t app:arg.1 -f arg . 
```

## CMD vs ENTRYPOINT

- `CMD` supplies the default command when used alone. 
- With an exec-form `ENTRYPOINT`, it supplies default arguments to that executable. 
- Arguments after the image name in `docker run` replace `CMD`; the `ENTRYPOINT` still runs.  
- Shell form (`CMD echo hello`) runs through a shell and does not pass arguments to an exec-form `ENTRYPOINT` the same way.

The two stages in [`Dockerfile`](./cmd_entrypoint) show both cases:

1. CMD only
```bash
docker build -f cmd_entrypoint --target cmd_only -t demo:cmd .
docker run --rm demo:cmd
docker run --rm demo:cmd echo replacement
```

2. ENTRYPOINT + CMD

```bash
docker build -f cmd_entrypoint -t demo:entrypoint .
docker run --rm demo:entrypoint
docker run --rm demo:entrypoint coisola
```

## Shell vs Exec mode

Exec form starts the program directly as the container's main process (PID 1). It receives stop signals, and Kubernetes reports its exit code.

```dockerfile
CMD ["echo", "hello"]
```

Shell form starts `/bin/sh -c` to run the command. If the shell remains as PID 1, it receives stop signals instead of the app, and Kubernetes reports the shell's exit code. The shell may not forward signals or preserve the app's exit code.

```dockerfile
CMD echo hello
```


## References
- https://docs.docker.com/reference/dockerfile/#understand-how-cmd-and-entrypoint-interact
- https://docs.docker.com/build/building/variables/#build-arguments
- https://docs.docker.com/get-started/docker-concepts/building-images/understanding-image-layers/
- https://docs.docker.com/build/building/variables/



# Image Layers and copy-on-write

Images are read-only.

Filesystem changes made by instructions such as `COPY` and `RUN` are stored in image layers. Once created, those layers are read-only. A running container sees them as one filesystem and gets its own writable layer. When the container changes a file from the image, the changed version is recorded in its writable layer; the original remains available to other containers. This is *copy-on-write* (CoW). Sharing the base avoids duplicating it for every container, and starting a container does not require copying the entire image first.

### How layers work`

[`layers_1`](./layers_1) creates a 200 MB temporary file and removes it before the instruction finishes:

```dockerfile
RUN dd if=/dev/zero of=/tmp/arquivo.bin bs=1M count=200 && \
  rm /tmp/arquivo.bin
```

The file consumes space while `dd` runs, but it is absent from the filesystem changes committed for that `RUN`. It does **not** add a 200 MB payload to the resulting image layer. The Go base image and executable still contribute their own size.

### The same removal in a later layer

[`layers_2`](./layers_2) uses the same Go app and paths, but separates those commands:

```dockerfile
RUN dd if=/dev/zero of=/tmp/arquivo.bin bs=1M count=200
RUN rm /tmp/arquivo.bin
```

The first `RUN` commits the 200 MB file. The second hides it from the final filesystem, but cannot rewrite the earlier layer. The image is therefore roughly 200 MB larger, even though `/tmp/arquivo.bin` is absent when a container starts.

```bash
docker build -f layers_2 -t dockerfile-layers-2 .
docker image ls dockerfile-layers-1
docker image ls dockerfile-layers-2
docker image history --human dockerfile-layers-2
```

Compare the two image sizes, then find the approximately 200 MB `dd` layer in the history of `dockerfile-layers-2`. Layer sizes may be reported in rounded units. Keeping creation and cleanup in one `RUN` avoids shipping that temporary data in the image.

### A container changes a file without changing the image

`COPY ./app ./` puts `main.go` at `/app/main.go`. The first command changes it in one container; the next creates a fresh container from the same image:

```bash
docker run --rm dockerfile-layers-1 sh -c 'printf "changed\n" > /app/main.go; cat /app/main.go'
# changed

docker run --rm dockerfile-layers-1 head -n 1 /app/main.go
# package main
```

The first container writes its own version; the image and the second container still have the original Go source. This is CoW at runtime. The `dd` comparison above shows the related rule during image construction: later filesystem changes do not rewrite earlier layers.

## Multi-stage: keep the binary, leave the toolchain behind

[`multi_stage`](./multi_stage) uses the same Go source and `/app/hello` output, then starts a small final stage:

```dockerfile
FROM golang:1.25 AS build
WORKDIR /app
COPY ./app ./
RUN CGO_ENABLED=0 go build -o /app/hello .

FROM alpine:3.20
COPY --from=build /app/hello /app/hello
CMD ["/app/hello"]
```

The important operation is `COPY --from=build`: it transfers the finished executable from the `build` stage into the final stage. The Go compiler, source files, and other builder files are not part of the final image. `CGO_ENABLED=0` makes this small Go program independent of the builder's C libraries, so it can run on the Alpine base.

```bash
docker build -f multi_stage -t dockerfile-multistage .
docker run --rm dockerfile-multistage
docker image ls dockerfile-layers-1
docker image ls dockerfile-multistage
```

The first image includes the full Go base, which can be over 1 GB. The multi-stage image contains the compiled binary plus the small Alpine base and image metadata. Its exact size depends on the image versions and architecture; the commands above show the actual difference. A smaller image takes less data to push and pull and less space to store. The build machine may still retain builder layers and build cache locally, even though they are excluded from the final image.

For example, the builds checked for this document reported these `docker image ls` disk-usage values:

| Image | Size |
| --- | ---: |
| `dockerfile-layers-1` | 1.29 GB |
| `dockerfile-layers-2` | 1.50 GB |
| `dockerfile-multistage` | 15.7 MB |

These are example results, not guaranteed sizes on another machine. The difference between the first two images is the retained `dd` layer; the much larger drop in the final image comes from leaving the Go toolchain behind.

## `CMD` versus `ENTRYPOINT`

`layers_1` uses `CMD ["/app/hello"]`. It runs the Go program by default, but a command after the image name replaces that default:

```bash
docker run --rm dockerfile-layers-1
# Hello, Docker!
docker run --rm dockerfile-layers-1 ls /app
# lists the files in /app
```

[`entrypoint`](./entrypoint) starts from the smaller multi-stage image. It uses `ls` as an executable and `/app` (the directory containing the Go binary) as its default argument:

```dockerfile
FROM dockerfile-multistage
ENTRYPOINT ["ls"]
CMD ["/app"]
```

```bash
docker build -f entrypoint -t dockerfile-entrypoint .
docker run --rm dockerfile-entrypoint
# lists /app, including hello
docker run --rm dockerfile-entrypoint /etc
# lists /etc instead
```

With an exec-form `ENTRYPOINT`, `docker run ... /etc` replaces the `CMD` argument but keeps `ls` as the executable. For an application image, the same pattern can keep the application as the executable and use `CMD` for its default options. Using the bracketed **exec form** avoids an extra shell process and lets the executable receive container stop signals directly. `CMD` alone is also valid.

## References

- [Dockerfile reference](https://docs.docker.com/reference/dockerfile/)
- [Image layers and copy-on-write](https://docs.docker.com/engine/storage/drivers/)
- [Multi-stage builds](https://docs.docker.com/build/building/multi-stage/)
