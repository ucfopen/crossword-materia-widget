
# Crossword: A Materia Widget

A quiz tool that uses words and clues to randomly generate a crossword puzzle. Crossword is designed for use with [Materia](https://github.com/ucfopen/Materia), an open-source platform for interactive course content developed by the University of Central Florida.

### Basic Use

In a production evironment, Crossword is installed to your Materia instance and is accessed via the Widget Catalog. For development, Crossword is bundled with the [Materia Widget Development Kit](https://github.com/ucfopen/Materia-Widget-Dev-Kit), which allows for rapid development in a local context using express.js.

### Setting Up and Running Locally

Clone the repository locally with git and install dependencies with `yarn` or `npm`:

```
$ yarn install
```

The widget can then be compiled for production use:

```
$ yarn run build
```

Or you can initialize the local express environment:

```
$ yarn run start
```

After which the development environment can be accessed via `localhost:8118/` in the browser.

### Installing To Materia

A widget is bundled into a `.wigt` file when ready to be shipped. The wigt file will always be present in the `build` directory once compiled: `build/_output/<widget name>.wigt` Alternatively, you can select **Download Package** in the top-right corner of the **Player** or **Creator** interface of the development environment, and select **Download .wigt**.

Another option, if you're using a local Materia instance for development, is to install directly through Docker: after clicking the previously mentioned **Download Package** option, select **Install to Docker Materia**.

For manual installation, copy the `.wigt` file to the following directory within your local Materia instance, then run the installation script located within the `docker` subdirectory:
```
$ cp build/_output/crossword.wigt /path/to/local/materia/fuel/app/tmp/widget_packages/
$ cd /path/to/local/materia/docker
$ ./run_widgets_install.sh crossword.wigt
```

For more information about the widget development process, be sure to visit the [documentation page](https://ucfopen.github.io/Materia-Docs/develop/widget-developer-guide.html) for Materia.
