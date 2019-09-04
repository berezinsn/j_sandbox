You can easily preconfigure jenkins with groovy scripts by adding new one into ./master/preconfigure folded
To start the jenkins sandbox deployment by using the script ./j-build.sh
To stop compose-services according with jenkins use command '''make stop '''
If you want to delete all stopped containers and images and rebuild it again - use command '''docker system prune -af''' after '''make stop '''

