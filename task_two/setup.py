import setuptools

REQUIRED_PACKAGES = ['apache_beam==2.8.3', 'apache_beam[interactive]==0.3.0']

setuptools.setup(
    name='setup',
    version='0.0.1',
    description='install module',
    install_requires=REQUIRED_PACKAGES,
    packages=setuptools.find_packages()
)
