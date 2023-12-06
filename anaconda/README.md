The idea of these files are to be a base so that we're all using the same versions of important packages like qutip. Likely you will need to add additional packages for your workflow. For example if you want to add scqubits to your environment, you should copy the base yml from this repository and add your own entry for scqubits before installing it.

# How to Install Conda Environment Using File

```
conda env create -f env.yml
```

# How to Remove Conda Environment

```
conda remove --name env --all
```