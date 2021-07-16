# POD Configs

This directory contains all the configurations that are needed to run a test on physical or emulated hardware.

It contains two subdirectories:
- `hardware`: contains all the information regarding the physical layout of a pod
- `workflow`: contains all the information regarding traffic tagging and client/rg setup (these configuration are specific to a physical POD and a workflow)

## Validating POD Configurations

The POD configurations contained in this folder needs to adhere to a specific schema that is described in:
- `hardware-config-schema.yaml`: for all hardware related configurations
- `workflow-config-schema.yaml`: for all workflows specific configurations

The two different configurations can be validated with:

```shell
pip3 install pykwalify

pykwalify -s hardware-config-schema.yaml -d hardware/hardware-config-example.yaml
pykwalify -s workflow-config-schema.yaml -d workflow/workflow-config-example.yaml
```
TODO add a `make` target to run validation on all the configurations