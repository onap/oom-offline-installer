from docs_conf.conf import *

branch = 'latest'
master_doc = 'index'

linkcheck_ignore = [
    'http://localhost',
]

intersphinx_mapping = {}

html_last_updated_fmt = '%d-%b-%y %H:%M'

exclude_patterns = ['.tox/**']

def setup(app):
    app.add_css_file("css/ribbon_onap.css")
