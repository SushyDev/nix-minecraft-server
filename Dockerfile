# --- Build dependencies
FROM nixos/nix:latest AS build

RUN mkdir -p /root/.config/nix && \
	echo "experimental-features = nix-command flakes" > /root/.config/nix/nix.conf

WORKDIR /tmp

COPY flake.nix flake.lock ./

RUN nix build

RUN mkdir /tmp/nix-store-closure && mkdir /tmp/tmp

RUN cp -R $(nix-store -qR result/) /tmp/nix-store-closure

# --- Construct final image
FROM scratch

COPY --from=build /tmp/result/ /build
COPY --from=build /tmp/nix-store-closure/ /nix/store/
COPY --from=build /tmp/tmp /tmp

WORKDIR /data
ENV MINECRAFT_DATA=/data
VOLUME /data

ENTRYPOINT ["/build/bin/minecraft-server"]
