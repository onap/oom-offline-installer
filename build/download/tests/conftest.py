import pytest
from download import *
from sys import version_info,exit
from test_settings import *
from timeit import default_timer
from docker import from_env

@pytest.fixture
def check_python_version():
    if version_info.major < 3:
        print('Python 2 is not supported.')
        exit(1)

@pytest.fixture
def init_cli(check_python_version): # pylint: disable=E0613,W0613
    # initialize DockerDownloader
    args = parse_args().parse_args(['--docker', TEST_IMAGE_LIST_FILE]) # pylint: disable=E0602
    interval_start = default_timer()
    docker = docker_downloader.DockerDownloader(False, *args.docker, mirror=args.docker_private_registry_mirror, mirror_exclude=args.docker_private_registry_exclude, workers=1) # pylint: disable=E0602
    handle_download(docker, args.check, [], interval_start) # pylint: disable=E0602

@pytest.fixture
def init_cli_with_registry_mirror(check_python_version): # pylint: disable=E0613,W0613
    # initialize DockerDownloader
    args = parse_args().parse_args(['--docker-private-registry-mirror', TEST_REGISTRY_MIRROR, '--docker', TEST_IMAGE_LIST_FILE]) # pylint: disable=E0602
    interval_start = default_timer()
    docker = docker_downloader.DockerDownloader(False, *args.docker, mirror=args.docker_private_registry_mirror, mirror_exclude=args.docker_private_registry_exclude, workers=1) # pylint: disable=E0602
    handle_download(docker, args.check, [], interval_start) # pylint: disable=E0602

@pytest.fixture
def init_cli_check(check_python_version, capfd): # pylint: disable=W0613
    # initialize DockerDownloader
    args = parse_args().parse_args(['--docker', TEST_IMAGE_LIST_FILE, '--check']) # pylint: disable=E0602
    interval_start = default_timer()
    docker = docker_downloader.DockerDownloader(False, *args.docker, mirror=args.docker_private_registry_mirror, mirror_exclude=args.docker_private_registry_exclude, workers=1) # pylint: disable=E0602
    handle_download(docker, args.check, [], interval_start) # pylint: disable=E0602
    msg = capfd.readouterr()
    return msg.out

@pytest.fixture
def test_image_list():
    img_list = []
    with open(TEST_IMAGE_LIST_FILE, 'r') as list:
        for line in list:
            img_list.append(line.strip())
    return img_list

@pytest.fixture
def docker_image_list():
    docker_client = from_env()
    image_list = []
    for img in docker_client.images.list():
        for tag in img.tags:
            image_list.append(tag)
    return image_list

@pytest.fixture
def drop_test_images(test_image_list, docker_image_list):
    dc = from_env()
    image_list = docker_image_list
    for img in test_image_list:
        if img in image_list:
            dc.images.remove(img)
