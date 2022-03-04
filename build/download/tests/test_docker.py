import pytest # pylint: disable=W0611
from docker import from_env # pylint: disable=W0611

# Library routines

def parse_check_output(mode, test_image_list, output):
    '''mode - True|False'''
    # for each test image check if it's marked as "True or False" (depending on mode) in fixture output
    for image in test_image_list:
        found = 0
        for line in output.split('\n'):
            if (image in line) and (mode in line):
                found = 1
                break
        if not found:
            print('ERROR: Image {} was not reported by "--check" option as {}'.format(image,mode))
            assert 0
    assert 1

# Actual test routines

def test_check_mode_images_not_pulled(drop_test_images, init_cli_check, test_image_list): # pylint: disable=W0613
    parse_check_output("False", test_image_list, init_cli_check)

def test_pull_images_from_mirror(init_cli_with_registry_mirror, test_image_list, init_cli_check): # pylint: disable=W0613
    parse_check_output("True", test_image_list, init_cli_check)

def test_pull_images(drop_test_images, init_cli, test_image_list, init_cli_check): # pylint: disable=W0613
    parse_check_output("True", test_image_list, init_cli_check)

def test_cleanup_images(drop_test_images): # pylint: disable=W0613
    # Noop routine to cleanup test images
    assert 1
