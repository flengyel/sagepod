#!/bin/bash
# updating bind mount permissions
for BINDMOUNT in ~/Jupyter ~/.jupyter; do
    sudo find ${BINDMOUNT} -type d -exec sudo chmod 775 {} \; -print
    sudo find ${BINDMOUNT} -type f -exec sudo chmod 664 {} \; -print
    sudo chown -R sage:sage ${BINDMOUNT}
done

