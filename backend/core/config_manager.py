import os
import sys

def get_base_dir() -> str:
    """Returns directory containing the EXE or project root."""
    if getattr(sys, "frozen", False):
        return os.path.dirname(os.path.abspath(sys.executable))
    return os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def get_config_dir() -> str:
    config_dir = os.path.join(get_base_dir(), "config")
    os.makedirs(config_dir, exist_ok=True)
    return config_dir

def get_data_dir() -> str:
    data_dir = os.path.join(get_base_dir(), "data")
    os.makedirs(data_dir, exist_ok=True)
    return data_dir

def get_config_path(filename: str) -> str:
    return os.path.join(get_config_dir(), filename)

def get_data_path(filename: str) -> str:
    return os.path.join(get_data_dir(), filename)
