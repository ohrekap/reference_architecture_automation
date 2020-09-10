import os
import socket
from docker import DockerClient
from pathlib import Path

path = Path(os.getcwd())
wdir = str(path.parents[0])+'/terraform/azure/panorama/'

print('Logging in to Azure using device code...')

client = DockerClient()

volume = client.volumes.create(name='azurecli')

subscription = os.environ.get('SUBSCRIPTION')

container = client.containers.run('zenika/terraform-azure-cli:release-4.6_terraform-0.12.28_azcli-2.10.1', 'az login --use-device-code', auto_remove=True,
                                    volumes={'azurecli': {'bind': '/root/.azure/', 'mode': 'rw'}},
                                    volumes_from=socket.gethostname(), working_dir=wdir,
                                    detach=True)
# Monitor the log so that the user can see the console output during the run versus waiting until it is complete.
# The container stops and is removed once the run is complete and this loop will exit at that time.
for line in container.logs(stream=True):
    print(line.decode('utf-8').strip())

if subscription != '':
    print('Set the subscription...')
    container = client.containers.run('zenika/terraform-azure-cli:release-4.6_terraform-0.12.28_azcli-2.10.1', 'az account set --subscription='+subscription, auto_remove=True,
                                        volumes={'azurecli': {'bind': '/root/.azure/', 'mode': 'rw'}},
                                        volumes_from=socket.gethostname(), working_dir=wdir,
                                        detach=True)
    # Monitor the log so that the user can see the console output during the run versus waiting until it is complete.
    # The container stops and is removed once the run is complete and this loop will exit at that time.
    for line in container.logs(stream=True):
        print(line.decode('utf-8').strip())
    print('Done.')

pass
