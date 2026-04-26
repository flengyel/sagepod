#!/bin/bash
sage --version
sage -python -c "import pycryptosat; import pkgutil; print('pycryptosat OK')"
sage -python -c "import pycryptosat; import inspect; import pycryptosat as p; print(p.__version__)"
