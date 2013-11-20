Code-Checker
============

This is a small Sinatra app that checks pull request diffs and runs PHP CodeSniffer on them.  PHP CodeSniffer uses Drupal standards configuration.

If / when PHP CodeSniffer finds errors in the code found in the pull request, this app will post inline comments to that pull request on the line that the error happened, and with the error itself.

PHP CodeSniffer will also update the status of the pull request if applicable.

