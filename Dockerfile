# syntax=docker/dockerfile:1.7
# Rozszerzony frontend BuildKit – umożliwia użycie mount=type=ssh / mount=type=secret
# oraz innych zaawansowanych dyrektyw RUN --mount.

# ─── Etap 1: build ────────────────────────────────────────────────────────────
FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS build

ARG BUILDPLATFORM
ARG TARGETOS
ARG TARGETARCH

WORKDIR /src

# Pobranie kodu źródłowego z publicznego repozytorium GitHub
# przy użyciu klucza SSH (mount=type=ssh) – klucz NIE trafia do warstw obrazu.
# Jeśli repozytorium jest publiczne i nie wymaga SSH, można zastąpić to:
#   RUN --mount=type=cache,target=/root/.nuget/packages \
#       git clone https://github.com/<user>/<repo>.git .
RUN --mount=type=ssh \
    apk add --no-cache git openssh-client && \
    mkdir -p -m 0600 ~/.ssh && \
    ssh-keyscan github.com >> ~/.ssh/known_hosts && \
    git clone git@github.com:FabianSkrzypczynski/WeatherApp.git .

# Restore – z wykorzystaniem cache NuGet montowanego przez BuildKit
# (nie trafia do obrazu finalnego; reużywany między buildami).
RUN --mount=type=cache,target=/root/.nuget/packages,sharing=locked \
    --mount=type=cache,target=/src/WeatherApp/obj,sharing=locked \
    dotnet restore ./WeatherApp/WeatherApp.csproj \
        --disable-parallel \
        --runtime linux-musl-x64 \
        /p:RestoreFallbackFolders="" \
        /p:RestoreAdditionalProjectFallbackFolders=""

# Publish
RUN --mount=type=cache,target=/root/.nuget/packages,sharing=locked \
    --mount=type=cache,target=/src/WeatherApp/obj,sharing=locked \
    dotnet publish ./WeatherApp/WeatherApp.csproj \
        --configuration Release \
        --runtime linux-musl-x64 \
        --self-contained false \
        /p:NuGetFallbackFolder="" \
        /p:RestoreFallbackFolders="" \
        /p:RestoreAdditionalProjectFallbackFolders="" \
        /p:PublishTrimmed=false \
        /p:DebugType=none \
        /p:DebugSymbols=false \
        -o /app/publish

# ─── Etap 2: runtime ──────────────────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS runtime

LABEL org.opencontainers.image.authors="Fabian Skrzypczynski" \
      org.opencontainers.image.title="WeatherApp" \
      org.opencontainers.image.description="ASP.NET Core MVC weather application" \
      org.opencontainers.image.base.name="mcr.microsoft.com/dotnet/aspnet:8.0-alpine"

WORKDIR /app

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --from=build --chown=appuser:appgroup /app/publish .

USER appuser

ENV PORT=8080
ENV ASPNETCORE_URLS=http://+:8080

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD wget -qO- http://localhost:8080/ || exit 1

ENTRYPOINT ["dotnet", "WeatherApp.dll"]