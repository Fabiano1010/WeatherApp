# syntax=docker/dockerfile:1.7
FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS build

ARG BUILDPLATFORM
ARG TARGETOS
ARG TARGETARCH

WORKDIR /src

RUN --mount=type=secret,id=gh_token \
    apk add --no-cache git && \
    GH_TOKEN=$(cat /run/secrets/gh_token) && \
    git clone https://oauth2:${GH_TOKEN}@github.com/Fabiano1010/WeatherApp.git .


RUN --mount=type=cache,target=/root/.nuget/packages,sharing=locked \
    --mount=type=cache,target=/src/WeatherApp/obj,sharing=locked \
    dotnet restore ./WeatherApp/WeatherApp.csproj \
        --disable-parallel \
        --runtime linux-musl-x64 \
        /p:RestoreFallbackFolders="" \
        /p:RestoreAdditionalProjectFallbackFolders=""

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
