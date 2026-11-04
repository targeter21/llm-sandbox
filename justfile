# Directory containing this justfile (the installed llm-sandbox root)
root := justfile_directory()

# Absolute path of the running `just`, so recipes don't depend on PATH (the systemd service has a minimal one)
just := just_executable()

# Run startup maintenance: prune sandbox caches and rebuild all images
startup:
    {{root}}/bin/common-sandbox.sh --prune
    {{just}} --justfile {{root}}/justfile update-agent-sandbox

# Build and update the container images for all agents
update-agent-sandbox:
    podman pull docker.io/library/fedora:latest
    podman build -t agent-base-sandbox:latest -f {{root}}/images/Dockerfile.agent-base {{root}}/images
    podman build -t bob-dev-sandbox:latest -f {{root}}/images/Dockerfile.bob-base {{root}}/images
    podman build -t gemini-dev-sandbox:latest -f {{root}}/images/Dockerfile.gemini-base {{root}}/images
    podman build -t claude-dev-sandbox:latest -f {{root}}/images/Dockerfile.claude-base {{root}}/images
    podman image prune -f
