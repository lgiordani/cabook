# Chapter 4 - Database repositories

The basic in-memory repository I implemented for the project is enough to show the concept of the repository layer abstraction, as any other type of repository will follow the same idea. In the spirit of providing a simple but realistic solution, however, I believe it is worth reimplementing the repository layer with a proper database.

This gives me the chance to show you one of the big advantages of a clean architecture, namely the simplicity with which you can replace existing components with others, possibly based on a completely different technology.

## TODO

The clean architecture we devised in the previous chapters defines a use case that receives a repository instance as an argument and uses its `list` method to retrieve the contained entries. This allows the use case to form a very loose coupling with the repository, being connected only through the API exposed by the object and not to the real implementation. In other words, the use cases are polymorphic in respect to TODO the `list` method.

This is very important and it is the core of the clean architecture design. Being connected through an API, the use case and the repository can be replaced by different implementations at any time, given that the new implementation provide TODO(subjunctive) the requested API.

It is worth noting, for example, that the initialisation of the object is not part of the API the use cases are using, since the repository is initialised in the main script and not in each use case. The `__init__` method, thus, doesn't need to be the same among the repository implementation, which gives us a great deal of flexibility, as different storages may need different initialisation values.

The simple repository we implemented in one of the previous chapters was

``` python
class MemRepo:
    def __init__(self, data):
        self.data = data

    def list(self):
        return self.data
```

which interface is made of two parts: the initialisation and the `list` method. The `__init__` method accepts values because this specific object doesn't act as a long-term storage, so we are forced to pass some data every time we instantiate the class.

A repository based on a proper database will not need to be filled with data when initialised, its main job being that of storing data between sessions, but will nevertheless need to be initialised at least with the database address and access credentials.

Furthermore, we have to deal with a proper external system, so we need to devise a way to test the repository without the need of a running database engine in the background. Remember that we are creating a specific implementation of a repository, so everything will be tailored to TODO(?) the actual database system that we will choose.

## A repository based on Postgres

Let's start with a repository based on a popular SQL database, PostgreSQL TODO(correct name). It can be accessed from Python in many ways, but probably the best is through the SQLAlchemy TODO(correct name) interface. SQLAlchemy is an ORM, a package that maps objects (as in object-oriented) to a relational database, and can normally be found in web frameworks like Django or in standalone packages like this.

To connect the Rent-o-matic use cases to a repository implemented with Postgres we need to do TODO(X) things:

1. Create the `PostgresRepo` object, testing it against a mock of the real database engine
2. Set up the database engine locally with Docker, prepare the database tables and pre-fill it with data
3. Connect the two and check that everything works out of the box

### TODO




### Run Postgres in a Docker container

The easiest way to run Postgres locally is using the official Docker image. Provided you installed Docker in your system you can run the database engine with this command

``` sh
$ docker run --name rentomaticdb -e POSTGRES_PASSWORD=rentomaticdb -p 5432:5432 -d postgres
dbac308b22f61f4aa82ad8e42a0f44422c9236e643634f536e992129f3d9b889
```

This runs the `postgres` Docker image in detached mode `-d` in a container called `rentomaticdb`. It maps port 5432 of the container to the same port of the host with `-p 5432:5432` and sets the `POSTGRES_PASSWORD` environment variable which is used to set the password of the `postgres` user in the `postgres` database.

If the command is successful you should see the container among the running one using `docker ps`

``` sh
$ docker ps
CONTAINER ID  IMAGE     COMMAND                 CREATED         STATUS         PORTS                   NAMES
dbac308b22f6  postgres  "docker-entrypoint.s…"  19 seconds ago  Up 17 seconds  0.0.0.0:5432->5432/tcp  rentomaticdb
```

### Connect to the container and set up the database

Now you need to connect to Postgres to create a database for the current application. You can run `psql` from the same Docker image that you are using to run the database engine

``` sh
$ docker run -it --rm  postgres psql -h 172.17.0.1 -U postgres -d postgres
```

or run it directly if you installed it in your system

``` sh
$ psql -h localhost -U postgres -d postgres
```

Please note that if you run it in a container you need to use the IP address of the Docker bridge interface, which is usually 172.17.0.1. You can run `sudo ip addr show docker0` to find out the IP of that interface.

You should be asked for the password that we used when we run the database engine in the previos section, and once you are connected you should see a prompt similar to

```
psql (11.1 (Debian 11.1-1.pgdg90+1))
Type "help" for help.

postgres=#
```

At this point you can list the databases with the `\l` command

```
postgres=# \l
                                 List of databases
    Name    |  Owner   | Encoding |  Collate   |   Ctype    |   Access privileges   
------------+----------+----------+------------+------------+-----------------------
 postgres   | postgres | UTF8     | en_US.utf8 | en_US.utf8 | 
 template0  | postgres | UTF8     | en_US.utf8 | en_US.utf8 | =c/postgres          +
            |          |          |            |            | postgres=CTc/postgres
 template1  | postgres | UTF8     | en_US.utf8 | en_US.utf8 | =c/postgres          +
            |          |          |            |            | postgres=CTc/postgres
(3 rows)
```

Now create the database for the Rent-o-matic project

```
postgres=# CREATE DATABASE rentomatic;
```

which should be instantaneous, and your database is ready to be used

```
postgres=# \l
                                 List of databases
    Name    |  Owner   | Encoding |  Collate   |   Ctype    |   Access privileges   
------------+----------+----------+------------+------------+-----------------------
 postgres   | postgres | UTF8     | en_US.utf8 | en_US.utf8 | 
 rentomatic | postgres | UTF8     | en_US.utf8 | en_US.utf8 | 
 template0  | postgres | UTF8     | en_US.utf8 | en_US.utf8 | =c/postgres          +
            |          |          |            |            | postgres=CTc/postgres
 template1  | postgres | UTF8     | en_US.utf8 | en_US.utf8 | =c/postgres          +
            |          |          |            |            | postgres=CTc/postgres
(4 rows)
```

### Create the SQLalchemy file

The database we just created is obviously empty, so we need to create the table we will use to store the `Room` models. Instead of doing it in SQL, however, we can do it with SQLAlchemy, given that we already use it to query the database.

Install the packages

``` sh
$ pip install SQLAlchemy psycopg2
```

Create a file `postgres_init.oy` in the project main directory, alongside with TODO(alongside) `wsgi.py`

``` python
from sqlalchemy import Column, Integer, String, Float
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

Base = declarative_base()


class Room(Base):
    __tablename__ = 'room'

    id = Column(Integer, primary_key=True)

    code = Column(String(36), nullable=False)
    size = Column(Integer)
    price = Column(Integer)
    longitude = Column(Float)
    latitude = Column(Float)


engine = create_engine(
    'postgresql+psycopg2://postgres:rentomaticdb@localhost/rentomatic')

Base.metadata.create_all(engine)

Base.metadata.bind = engine

DBSession = sessionmaker(bind=engine)

session = DBSession()

room1 = {
    'code': 'f853578c-fc0f-4e65-81b8-566c5dffa35a',
    'size': 215,
    'price': 39,
    'longitude': '-0.09998975',
    'latitude': '51.75436293',
}

room2 = {
    'code': 'fe2c3195-aeff-487a-a08f-e0bdc0ec6e9a',
    'size': 405,
    'price': 66,
    'longitude': '0.18228006',
    'latitude': '51.74640997',
}

room3 = {
    'code': '913694c6-435a-4366-ba0d-da5334a611b2',
    'size': 56,
    'price': 60,
    'longitude': '0.27891577',
    'latitude': '51.45994069',
}

room4 = {
    'code': 'eed76e77-55c1-41ce-985d-ca49bf6c0585',
    'size': 93,
    'price': 48,
    'longitude': '0.33894476',
    'latitude': '51.39916678',
}

for r in [room1, room2, room3, room4]:
    new_room = Room(
        code=r['code'],
        size=r['size'],
        price=r['price'],
        longitude=r['longitude'],
        latitude=r['latitude']
    )
    session.add(new_room)
    session.commit()
```

Let's comment it section by section

``` python
from sqlalchemy import Column, Integer, String, Float
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

Base = declarative_base()
```

We need to import many things from the SQLAlchemy package to setup the database and to create the table. Remember that SQLAlchemy has a declarative approach, so we need to instantiate the `Base` object, and then to fill it with the classes that represent the tables.

``` python
class Room(Base):
    __tablename__ = 'room'

    id = Column(Integer, primary_key=True)

    code = Column(String(36), nullable=False)
    size = Column(Integer)
    price = Column(Integer)
    longitude = Column(Float)
    latitude = Column(Float)
```

This is the class that represents the `Room` in the database. It is important to understand that this not the class we are using in the business logic, but the class that we want to map in the SQL database. The structure of this class is thus dictated by the needs of the storage layer, and not by the use cases. You might want to store `longitude` and `latitude` in a JSON field, for example, to allow for easier extendibility, of for other reasons, without changing the definition of the domain model.

Obviously this means that you have to keep in sync the storage level with the domain one, and that you need to manage migrations on your own. You can still use tools like Alembic, obviously, the migrations will not come directly from domain model changes. My experience with migrations, however, is that in big production systems is almost always better to separate the two layers, so personally the clean architecture approach doesn't look like a big sacrifice.

``` python
engine = create_engine(
    'postgresql+psycopg2://postgres:rentomaticdb@localhost/rentomatic')

Base.metadata.create_all(engine)

Base.metadata.bind = engine

DBSession = sessionmaker(bind=engine)

session = DBSession()
```

The `engine` variable is the connection between SQLAlchemy and the running Postgres instance, which is why we pass a string containing the user name, the password, and the database name. In a real application the password would obviously be passed through an environment variable. The engine is then used by the declarative base to create all tables, and the engine is bound to the metadata to be used when creating a session.

``` python

room1 = {
    'code': 'f853578c-fc0f-4e65-81b8-566c5dffa35a',
    'size': 215,
    'price': 39,
    'longitude': '-0.09998975',
    'latitude': '51.75436293',
}

room2 = {
    'code': 'fe2c3195-aeff-487a-a08f-e0bdc0ec6e9a',
    'size': 405,
    'price': 66,
    'longitude': '0.18228006',
    'latitude': '51.74640997',
}

room3 = {
    'code': '913694c6-435a-4366-ba0d-da5334a611b2',
    'size': 56,
    'price': 60,
    'longitude': '0.27891577',
    'latitude': '51.45994069',
}

room4 = {
    'code': 'eed76e77-55c1-41ce-985d-ca49bf6c0585',
    'size': 93,
    'price': 48,
    'longitude': '0.33894476',
    'latitude': '51.39916678',
}

for r in [room1, room2, room3, room4]:
    new_room = Room(
        code=r['code'],
        size=r['size'],
        price=r['price'],
        longitude=r['longitude'],
        latitude=r['latitude']
    )
    session.add(new_room)
    session.commit()
```

We fill the database with some data that I prepared, the same data use to populate the in-memory repository. Remember that the session is a staging area and that you need to commit it after you changed its content.

https://www.pythoncentral.io/introductory-tutorial-python-sqlalchemy/
https://www.oreilly.com/library/view/essential-sqlalchemy-2nd/9781491916544/ch04.html
https://github.com/miki725/alchemy-mock
