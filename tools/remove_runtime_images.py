#!/usr/bin/env python3
import yaml
import sys
import argparse


class ModifiedParser(argparse.ArgumentParser):
    """
    modified error handling to print help
    """
    def error(self, message):
        sys.stderr.write('error: %s\n' % message)
        self.print_help()
        sys.exit(2)


def create_blacklist(config_file):
    """
    Generate a list of images which needs to be excluded from docker_image_list
    :param config_file: application_configuration file where images are.
    :return:
    """
    with open(config_file, 'r') as f:
        file = yaml.load(f, Loader=yaml.SafeLoader)

        blacklist=[]
        for name, _ in file['runtime_images'].items():
            blacklist.append(file['runtime_images'][name]['path'])
    return blacklist


def should_remove_line(line, blacklist):
    """
    Helping function to match image in blacklist
    :param line: line in datalist file
    :param blacklist: list of images to be removed
    :return
    """
    return any([image in line for image in blacklist])


def update_datalist(config_file, datalist):
    """
    remove local images from datalist.
    :param config_file: application_configuration file where images are.
    :param datalist: docker_image_list to be updated
    :return:
    """
    blacklist = create_blacklist(config_file)
    data = []
    with open(datalist, 'r') as f:
        for line in f:
            if not should_remove_line(line, blacklist):
                data.append(line)
    with open(datalist, 'w') as f:
        for line in data:
            f.write(line)


def run_cli():
    """
    Run as cli tool
    """

    parser = ModifiedParser(description='Remove runtime images from docker_image_list')

    parser.add_argument('config_file',
                        help='application_configuration file where images are')
    parser.add_argument('datalist',
                        help='docker_image_list from where images should be removed')
    args = parser.parse_args()

    update_datalist(args.config_file, args.datalist)


if __name__ == '__main__':
    run_cli()

