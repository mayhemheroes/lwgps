FROM debian:bookworm as builder
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y build-essential cmake clang
COPY . /LWGPS
WORKDIR /LWGPS/fuzz
RUN make

FROM debian:bookworm-slim
COPY --from=builder /LWGPS/fuzz/fuzz .