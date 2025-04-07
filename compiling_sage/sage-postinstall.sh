#!/bin/bash
#!/bin/bash
# run after successful install, no matter how successful

sage -i jupyterlab_widgets
jupyter nbextension install --py widgetsnbextension --user
jupyter nbextension enable widgetsnbextension --py --user

