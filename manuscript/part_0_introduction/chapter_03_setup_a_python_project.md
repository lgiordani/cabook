# Setup a Python Project

## Virtual environments

One of the first things you have to learn as a Python programmer is how to create, manage, and use your virtual environments. A virtual environment is nothing more than a directory (with many subdirectories) that mirrors a Python installation as the one that you can find in your operating system. This is a good way to isolate a specific version of Python and of the packages that are not part of the standard library.

This comes handy form many reasons. First of all, the Python version installed system-wide (your Linux distribution, your version of Mac OS, Windows, or other operating system) shouldn't be tampered with. That Python installation and its modules are managed by the maintainer of the operating system, and in general it's not a good idea to change things there unless you are sure of what you are doing. Having a single personal installation of Python, however, is usually not enough, as different project may have different requirements. For example, the newest version of a package might break the API compatibility and we are not ready to move the whole project to the new API, so we want to keep the version of that package fixed and avoid any update. At the same time another project may require the bleeding edge or even a fork of that package, for example when you have to patch a security issue or if you need a new feature and can't wait for the usual release cycle that can last for weeks.

Ultimately, the idea is that it is cheaper and simpler (at least in 2018) to copy the whole Python installation and to customise it than to try to manage a single installation that satisfies all the requirements. It's the same advantage we have using virtual machines, but on a smaller scale.

The starting point to become familiar with virtual environments is the [official documentation](https://docs.python.org/3/tutorial/venv.html), but if you experience issues with a specific version of your operating system you will find plenty of resources on Internet that may clarify the matter.

In general, I advise to have a different virtual environment for each Python project. You may prefer to keep them inside the project's directory or outside. In this latter case the name of the virtual environment shall reflect in some way the associated project. There are packages to manage the virtual environments that simplify your interaction with them, and the most famous one is [virtualenvwrapper](https://virtualenvwrapper.readthedocs.io/en/latest/).

I used to create my virtual environments inside the directory of my Python projects. Since I started using Cookiecutter (see next section) to create new projects, however, I switched to a different setup. Keeping the virtual environment outside the project allows me to install Cookiecutter in the virtualenv, instead of being forced to install it system-wide, which sometimes prevents me to use the latest version.

If you create the virtual environment in the project directory you have to configure your version control and other tools to ignore it. In particular, add it to [`.gitignore`](https://git-scm.com/docs/gitignore) if you use Git and to [`pytest.ini`](https://docs.pytest.org/en/latest/reference.html#confval-norecursedirs) if you use the pytest testing framework (like I do in the rest of the book).

## Python projects with Cookiecutter

Creating a Python project from scratch is not easy. There are many things to configure and manually writing all the files is something I suggest only if you strongly desire to understand how the Python distribution code works. If you want to focus on your project, instead, you'd better use a template.

[Cookiecutter](https://cookiecutter.readthedocs.io/en/latest/) is a simple but very powerful Python software created by Audrey Roy Greenfeld that creates files and directories from a template. It creates directories and files, and manages to create very complex set-ups just asking you a handful of questions. There are already templates for Python (obviously), C, Scala, LaTeX, Go, and other languages, and creating your own template is very simple.

The [official Python template](https://github.com/audreyr/cookiecutter-pypackage) is maintained by the same author of Cookiecutter. Other Python templates with different set-ups or that rely on different tools are available, and some of them are linked in the Cokkiecutter README file.

I maintain [a Python project template](https://github.com/lgiordani/cookiecutter-pypackage) that I will use throughout the book. You are not forced to use it, actually I encourage you to fork it and change what you don't like as soon as you get comfortable with the structure and the role that the various files have.

These templates work perfectly for open source projects. If you are creating a closed source project you will not need some of the files (like the license or the instructions for programmers who want to collaborate), but you can always delete them after you applied the template. If you need to do this more than once, you can fork the template and change it to suit your needs.

A small issue you might run into is that Cookiecutter is a Python program, and thus it requires to be installed in your Python environment. In general it is safe to install such a package in the system-wide Python, as it is not a library and it is not going to change the behaviour of important components in the system, but if you want to be safe and flexible I advise you to follow this procedure

* Create a virtual environment for the project, using one of the methods discussed in the previous section, and activate it
* Install Cookiecutter with `pip install cookiecutter`
* Run Cookiecutter with your template of choice `cookiecutter <template_URL>`, answering the questions
* Install the requirements following the instructions of the template itself `pip install -r <requirements_file>`

Refer to the `README` of the Cookiecutter template to better understand the questions that the program will ask you and remember that if you make a mistake you can always delete the project and run Cookiecutter again.


