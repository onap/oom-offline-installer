Role to install bash-completion
===============================

Role that installs the bash-completion package and generates the completion code for binary which name is passed via role parameter.

Requirements
------------

For the role to operate properly it is expected that the binary for which the completion code is generated supports "completion bash" option.

Role Variables
--------------

- completion\_bin (role's parameter) - name of the binary for which the completion code will be generated

