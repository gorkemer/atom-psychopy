# psychopy package

The standalone version of [PsychoPy](http://www.psychopy.org/) offers an IDE that is great to start programming experiments very fast. However, at some point I wanted the programming experience of a *real* editor. I wanted to keep compatibility with the standalone PsychoPy Python framework. This package can launch experiment files (\*.py) from within the environment of a standalone PsychoPy installation.

## TODO
- write tests
- compatibility with Windows/Linux (add defaults for paths)
- documentation
- for now concurrent console output is not possible because of the bufferedProcess way of spawning the python process (see [here](https://github.com/rgbkrk/atom-script/issues/497))

This package relies to a great part on the [script package](https://atom.io/packages/script) by [rgbkrk](https://atom.io/users/rgbkrk).
