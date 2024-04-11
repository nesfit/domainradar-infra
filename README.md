# domainradar
DomainRadar

# How to run:

The script `build_images.sh` is required because we're working with private
repositories... it clones everything in the "local" context where we assume we
have configured access to these private repositories and then calls the
individual docker image build commands to build the local images.

After that we can build the docker-compose services and start them.

```bash
./build_images.sh
docker-compose build
docker-compose up
```
