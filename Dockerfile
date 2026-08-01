# The base image contains the workspace dependencies and generated contract
# artifacts required by the relayer build. Pin it so devnet builds are
# reproducible instead of changing whenever the `latest` tag moves.
ARG RELAYER_PLATFORM=linux/amd64
FROM --platform=${RELAYER_PLATFORM} bisht13/relayer-base@sha256:1e5989da25713c89577b2a61ccbc2292a490625f41c818fecf5ca878b234e4fc

# Replace the stale workspace in the base image so removed source files and
# artifacts cannot leak into this build.
WORKDIR /relayer
RUN rm -r packages rust-toolchain.toml
COPY package.json yarn.lock Cargo.toml Cargo.lock rust-toolchain ./
COPY packages/contracts packages/contracts
COPY packages/relayer /relayer/packages/relayer

# Rebuild the contract artifacts consumed by the relayer's build script.
RUN . $HOME/.nvm/nvm.sh && nvm use default && yarn install --frozen-lockfile
RUN . $HOME/.bashrc && cd packages/contracts && forge build --skip '*ZKSync*'

WORKDIR /relayer/packages/relayer

# Honor the checked-in dependency graph. Without --locked, Cargo refreshes the
# branch-based relayer-utils dependency and can select an incompatible revision.
RUN cargo build --locked --release

# Expose port
EXPOSE 4500

# The relayer only needs read access to its mounted configuration and templates.
USER 65534:65534

# Run the artifact built above instead of invoking Cargo again at startup.
CMD ["/relayer/target/release/email-tx-builder-relayer"]
