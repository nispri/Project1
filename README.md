To start the server

npm run dev


---------------------

This project is created to teach you how to create a Restful CRUD API with Node.js, Express and MongoDB.


API Features
The application can create, read, update and delete data, for example: products, in a database.



After Sonar Server Restart, make sure to start the sonar conatiner
docker run -d --name sonar -p 9000:9000 sonarqube:lts-community

docker start sonar

docker stop node-api
docker rm node-api

