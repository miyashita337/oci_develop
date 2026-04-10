"""Smoke tests to verify project structure."""
import os

def test_project_has_requirements():
    assert os.path.exists('requirements.txt')

def test_project_directories_exist():
    # At least one source directory should exist
    dirs = ['bitcoin', 'rate-exchange', 'us_bonds']
    assert any(os.path.isdir(d) for d in dirs)
