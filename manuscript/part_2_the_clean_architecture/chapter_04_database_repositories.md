TODO(the code changed, the name of the fixtures changed)


# Chapter 4 - Database repositories

The basic in-memory repository I implemented for the project is enough to show the concept of the repository layer abstraction, and any other type of repository will follow the same idea. In the spirit of providing a simple but realistic solution, however, I believe it is worth reimplementing the repository layer with a proper database.

This gives me the chance to show you one of the big advantages of a clean architecture, namely the simplicity with which you can replace existing components with others, possibly based on a completely different technology.

## Introduction

The clean architecture we devised in the previous chapters defines a use case that receives a repository instance as an argument and uses its `list` method to retrieve the contained entries. This allows the use case to form a very loose coupling with the repository, being connected only through the API exposed by the object and not to the real implementation. In other words, the use cases are polymorphic in respect of the `list` method.

This is very important and it is the core of the clean architecture design. Being connected through an API, the use case and the repository can be replaced by different implementations at any time, given that the new implementation provides the requested interface.

It is worth noting, for example, that the initialisation of the object is not part of the API that the use cases are using, since the repository is initialised in the main script and not in each use case. The `__init__` method, thus, doesn't need to be the same among the repository implementation, which gives us a great deal of flexibility, as different storages may need different initialisation values.

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

Furthermore, we have to deal with a proper external system, so we have to devise a strategy to test it, as this might require a running database engine in the background. Remember that we are creating a specific implementation of a repository, so everything will be tailored to the actual database system that we will choose.

## A repository based on PostgreSQL

Let's start with a repository based on a popular SQL database, PostgreSQL[^postgresql]. It can be accessed from Python in many ways, but the best is probably through the SQLAlchemy[^sqlalchemy] interface. SQLAlchemy is an ORM, a package that maps objects (as in object-oriented) to a relational database, and can normally be found in web frameworks like Django or in standalone packages like the one we are considering.

[^postgresql]: https://www.postgresql.org
[^sqlalchemy]: https://www.sqlalchemy.org

The important thing about ORMs is that they are very good example of something you shouldn't try to mock. Properly mocking the SQLAlchemy structures that are used when querying the DB results in very complex code that is difficult to write and almost impossible to maintain as every single change in the queries results in a series of mocks that have to be written again.[^query]

[^query]: unless you consider things like `sessionmaker_mock()().query.assert_called_with(Room)` something attractive. And this was by far the simplest mock I had to write.

We need therefore to set up an integration test. The idea is to create the DB, set up the connection with SQLAlchemy, test the condition we need to check, and destroy the database. Since the action of creating and destroying the DB can be expensive in terms of time we might want to do it just at the beginning and at the end of the whole test suite, but even with this change the tests will be slow. This is why we will also need to use labels to avoid running them every time we run the suite. Let's face this complex task one step at a time.

### Label integration tests

The first thing we need to do is to label integration tests, exclude them by default and create a way to run them. Since pytest supports labels, called _marks_, we can use this feature to add a global mark to a whole module. Create the `tests/repository/test_postgresrepo.py` file and put in it this code

``` python
import pytest

pytestmark = pytest.mark.integration


def test_dummy():
    pass
```

The `pytestmark` module attribute labels every test in the module with the `integration` tag. To verify that this works I added a `test_dummy` test function which passes always. You can run `py.test -svv -m integration` now to ask pytest to run only the tests marked with that label. The `-m` option supports a rich syntax that you can learn reading the documentation [^pytestmarks]

[^pytestmarks]: https://docs.pytest.org/en/latest/example/markers.html

While this is enough to run integration tests selectively, it is not enough to skip them by default. To do this we can alter the pytest setup to label all those tests as skipped, but this will give us no means to run them. The standard way to implement this is to define a new command line option and to process each marked test according to the value of this option.

To do it open the `tests/conftest.py` that we already created and add the following code

``` python
def pytest_addoption(parser):
    parser.addoption("--integration", action="store_true",
                     help="run integration tests")


def pytest_runtest_setup(item):
    if 'integration' in item.keywords and not item.config.getvalue("integration"):
        pytest.skip("need --integration option to run")
```

The first function is a hook into the pytest CLI parser that adds the `--integration` option. When this option is specified on the command line the pytest setup will contain the key `integration` with value `True`.

The second function is a hook into the pytest setup of each single test. The `item` variable contains the test itself (actually a `_pytest.python.Function` object), which in turn contains two useful pieces of information. The first is the `item.keywords` attribute, that contains the test marks, alongside many other interesting things like the name of the test, the file, the module, and also information about the patches that happen inside the test. The second is the `item.config` attribute that contains the parsed pytest command line.

So, if the test is marked with `integration` (`'integration' in item.keywords`) and the `--integration` option is not present (`not item.config.getvalue("integration")`) the test is skipped.

### Create the SQLalchemy file

Creating and populating the test database with initial data will be part of the test suite, but we need to define somewhere the tables that will be contained in the database. This is where SQLAlchemy's ORM comes into play, as we will define those tables in terms of Python objects.

Add the packages `SQLAlchemy` to the `prod.txt`[^prod] requirements file and update the installed packages with

``` sh
$ pip install -r requirements/dev.txt
```

[^prod]: TODO explain why prod and dev

Create the `rentomatic/repository/postgres_objects.py` file with the following content

``` python
from sqlalchemy import Column, Integer, String, Float
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()


class Room(Base):
    __tablename__ = 'room'

    id = Column(Integer, primary_key=True)

    code = Column(String(36), nullable=False)
    size = Column(Integer)
    price = Column(Integer)
    longitude = Column(Float)
    latitude = Column(Float)
```

Let's comment it section by section

``` python
from sqlalchemy import Column, Integer, String, Float
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()
```

We need to import many things from the SQLAlchemy package to setup the database and to create the table. Remember that SQLAlchemy has a declarative approach, so we need to instantiate the `Base` object and then use it as a starting point to declare the tables/objects.

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

This is the class that represents the `Room` in the database. It is important to understand that this not the class we are using in the business logic, but the class that we want to map into the SQL database. The structure of this class is thus dictated by the needs of the storage layer, and not by the use cases. You might want for instance to store `longitude` and `latitude` in a JSON field, to allow for easier extendibility, without changing the definition of the domain model. In the simple case of the Rent-o-matic project the two classes almost overlap, but this is not the case generally speaking.

Obviously this means that you have to keep in sync the storage and the domain levels, and that you need to manage migrations on your own. You can obviously use tools like Alembic, but the migrations will not come directly from domain model changes.

### Spin up and tear down the database container

When we run the integration tests the Postgres database engine must be already running in background, and it must be already configured, for example with a pristine database ready to be used. Moreover, when all the tests have been executed the database should be removed and the database engine stopped.

This is a perfect job for Docker, which can run complex systems in isolation with minimal configuration. We might orchestrate the creation and destruction of the database with bash, but this would mean wrapping the test suite in another script which is not my favourite choice.

The structure that I show you here makes use of docker-compose through the `pytest-docker`, `pyyaml`, and `sqlalchemy-utils` packages. The idea is simple: given the configuration of the database (name, user, password), we create a temporary file containing the docker-compose configuration that spins up a Postgres database. Once the Docker container is running, we connect to the database engine with SQLAlchemy to create the database we will use for the tests and we populate it. When all the tests have been executed we tear down the Docker image and we leave the system in a clean status.

Due to the complexity of the problem and a limitation of the `pytest-docker` package, the resulting setup is a bit convoluted. The `pytest-docker` plugin requires you to create a `docker_compose_file` fixture that should return the path of a file with the docker-compose configuration (YAML syntax). The plugin provides two fixtures, `docker_ip` and `docker_services`: the first one is simply the IP of the docker host (which can be different from localhost in case of remote execution) while the second is the actual routine that runs the containers through docker-compose and stops them after the test session. My setup to run this plugin is complex, but it allows me to keep all the database information in a single place.

The first fixture goes in `tests/conftest.py` and contains the information about the PostgreSQL connection, namely the host, the database name, the user name, and the password

``` python
@pytest.fixture(scope='session')
def docker_setup(docker_ip):
    return {
        'postgres': {
            'dbname': 'rentomaticdb',
            'user': 'postgres',
            'password': 'rentomaticdb',
            'host': docker_ip
        }
    }
```

This way I have a single source of parameters that I will use to spin up the Docker container, but also to set up the connection with the container itself during the tests.

The other two fixtures in the same file are the one that creates a temporary file and a one that creates the configuration for docker-compose and stores it in the previously created file.

``` python
@pytest.fixture(scope='session')
def docker_tmpfile():
    f = tempfile.mkstemp()
    yield f
    os.remove(f[1])


@pytest.fixture(scope='session')
def docker_compose_file(docker_tmpfile, docker_setup):
    content = {
        'version': '3.1',
        'services': {
            'postgresql': {
                'restart': 'always',
                'image': 'postgres',
                'ports': ["5432:5432"],
                'environment': [
                    'POSTGRES_PASSWORD={}'.format(
                        docker_setup['postgres']['password']
                    )
                ]
            }
        }
    }

    f = os.fdopen(docker_tmpfile[0], 'w')
    f.write(yaml.dump(content))
    f.close()

    return docker_tmpfile[1]
```

The `pytest-docker` plugin leaves to us the task of defining a function to check if the container is responsive, as the way to do it depends on the actual system that we are running (in this case PostgreSQL). I defined the function in `tests/repository/postgres/conftest.py`

``` python
def pg_is_responsive(ip, docker_setup):
    try:
        conn = psycopg2.connect(
            "host={} user={} password={} dbname={}".format(
                ip,
                docker_setup['postgres']['user'],
                docker_setup['postgres']['password'],
                'postgres'
            )
        )
        conn.close()
        return True
    except psycopg2.OperationalError as exp:
        return False
```

As you can see the function relies on a setup dictionary like the one that we defined in the `docker_setup` fixture (the input argument is aptly named the same way) and returns a boolean after having checked if it is possible to establish a connection with the server.

The final fixture related to docker-compose is `pg_engine` which makes use of what I defined previously to create the connection with the PostgreSQL database

``` python
@pytest.fixture(scope='session')
def pg_engine(docker_ip, docker_services, docker_setup):
    docker_services.wait_until_responsive(
        timeout=30.0, pause=0.1,
        check=lambda: pg_is_responsive(docker_ip, docker_setup)
    )

    conn_str = "postgresql+psycopg2://{}:{}@{}/{}".format(
        docker_setup['postgres']['user'],
        docker_setup['postgres']['password'],
        docker_setup['postgres']['host'],
        docker_setup['postgres']['dbname']
    )
    engine = sqlalchemy.create_engine(conn_str)
    sqlalchemy_utils.create_database(engine.url)

    conn = engine.connect()

    yield engine

    conn.close()
```

As you can see the fixture yields the SQLAlchemy `engine` object, so it can be correctly closed once the session is finished.

### Database fixtures

With the `pg_engine` fixture we can define higher-level functions such as `pg_session_empty` that gives us access to the pristine database, `pg_data`, which defines some values for the test queries, and `pg_session` that creates the rows of the `Room` table using the previous two fixtures.

``` python
@pytest.fixture(scope='session')
def pg_session_empty(pg_engine):
    Base.metadata.create_all(pg_engine)

    Base.metadata.bind = pg_engine

    DBSession = sqlalchemy.orm.sessionmaker(bind=pg_engine)

    session = DBSession()

    yield session

    session.close()


@pytest.fixture(scope='function')
def pg_data():
    return [
        {
            'code': 'f853578c-fc0f-4e65-81b8-566c5dffa35a',
            'size': 215,
            'price': 39,
            'longitude': -0.09998975,
            'latitude': 51.75436293,
        },
        {
            'code': 'fe2c3195-aeff-487a-a08f-e0bdc0ec6e9a',
            'size': 405,
            'price': 66,
            'longitude': 0.18228006,
            'latitude': 51.74640997,
        },
        {
            'code': '913694c6-435a-4366-ba0d-da5334a611b2',
            'size': 56,
            'price': 60,
            'longitude': 0.27891577,
            'latitude': 51.45994069,
        },
        {
            'code': 'eed76e77-55c1-41ce-985d-ca49bf6c0585',
            'size': 93,
            'price': 48,
            'longitude': 0.33894476,
            'latitude': 51.39916678,
        }
    ]


@pytest.fixture(scope='function')
def pg_session(pg_session_empty, pg_data):
    for r in pg_data:
        new_room = Room(
            code=r['code'],
            size=r['size'],
            price=r['price'],
            longitude=r['longitude'],
            latitude=r['latitude']
        )
        pg_session_empty.add(new_room)
        pg_session_empty.commit()

    yield pg_session_empty

    pg_session_empty.query(Room).delete()
```

Note that this last fixture has a `function` scope, thus it is run for every test. Therefore, we delete all rooms after the yield returns, leaving the database in the same state it had before the test. This is not strictly necessary in this particular case, as during the tests we are only reading from the database, so we might add the rooms at the beginning of the test session and just destroy the container at the end of it. This doesn't however work in general, for instance when tests add entries to the database, so I preferred to show you a more generic solution.

We can test this whole setup changing the `test_dummy` function so that is fetches all the rows of the `Room` table and verifying that the query returns 4 values 

``` python
import pytest
from rentomatic.repository.postgres_objects import Room

pytestmark = pytest.mark.integration


def test_dummy(pg_session):
    assert len(pg_session.query(Room).all()) == 4
```

### Integration tests

At this point we can create the real tests in the `tests/repository/postgres/test_postgresrepo.py` file. The first function is `test_repository_list_without_parameters` which runs the `list` method without any argument. The test receives the `docker_setup` fixture that allows us to initialise the `PostgresRepo` class, the `pg_data` fixture with the test data that we put in the database, and the `pg_session` fixture that creates the actual test database in the background. The actual test code compares the codes of the rooms returned by the `list` method and the test data of the `pg_data` fixture.

``` python
def test_repository_list_without_parameters(
        docker_setup, pg_data, pg_session):
    repo = postgresrepo.PostgresRepo(docker_setup['postgres'])

    repo_rooms = repo.list()

    assert set([r.code for r in repo_rooms]) == \
        set([r['code'] for r in pg_data])
```

The rest of the test suite is basically doing the same. Each test creates the PostgresRepo object, it runs its `list` method with a given value of the `filters` argument, and compares the actual result with the expected one.

``` python
def test_repository_list_with_code_equal_filter(
        docker_setup, pg_data, pg_session):
    repo = postgresrepo.PostgresRepo(docker_setup['postgres'])

    repo_rooms = repo.list(
        filters={'code__eq': 'fe2c3195-aeff-487a-a08f-e0bdc0ec6e9a'}
    )

    assert len(repo_rooms) == 1
    assert repo_rooms[0].code == 'fe2c3195-aeff-487a-a08f-e0bdc0ec6e9a'


def test_repository_list_with_price_equal_filter(
        docker_setup, pg_data, pg_session):
    repo = postgresrepo.PostgresRepo(docker_setup['postgres'])

    repo_rooms = repo.list(
        filters={'price__eq': 60}
    )

    assert len(repo_rooms) == 1
    assert repo_rooms[0].code == '913694c6-435a-4366-ba0d-da5334a611b2'


def test_repository_list_with_price_less_than_filter(
        docker_setup, pg_data, pg_session):
    repo = postgresrepo.PostgresRepo(docker_setup['postgres'])

    repo_rooms = repo.list(
        filters={'price__lt': 60}
    )

    assert len(repo_rooms) == 2
    assert set([r.code for r in repo_rooms]) ==\
        {
            'f853578c-fc0f-4e65-81b8-566c5dffa35a',
            'eed76e77-55c1-41ce-985d-ca49bf6c0585'
    }


def test_repository_list_with_price_greater_than_filter(
        docker_setup, pg_data, pg_session):
    repo = postgresrepo.PostgresRepo(docker_setup['postgres'])

    repo_rooms = repo.list(
        filters={'price__gt': 48}
    )

    assert len(repo_rooms) == 2
    assert set([r.code for r in repo_rooms]) ==\
        {
            '913694c6-435a-4366-ba0d-da5334a611b2',
            'fe2c3195-aeff-487a-a08f-e0bdc0ec6e9a'
    }


def test_repository_list_with_price_between_filter(
        docker_setup, pg_data, pg_session):
    repo = postgresrepo.PostgresRepo(docker_setup['postgres'])

    repo_rooms = repo.list(
        filters={
            'price__lt': 66,
            'price__gt': 48
        }
    )

    assert len(repo_romos) == 1
    assert repo_rooms[0].code == '913694c6-435a-4366-ba0d-da5334a611b2'
```

Remember that I introduced these tests one at a time, and that I'm not showing you the full TDD work flow only for brevity's sake. The code of the `PostgresRepo` class has been developed following a strict TDD approach, and I recommend you to do the same. The resulting code goes in `rentomatic/repository/postgresrepo.py`, in the same directory were we create the `postgres_objects.py` file.

``` python
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from rentomatic.domain import room
from rentomatic.repository.postgres_objects import Base, Room


class PostgresRepo:
    def __init__(self, connection_data):
        connection_string = "postgresql+psycopg2://{}:{}@{}/{}".format(
            connection_data['user'],
            connection_data['password'],
            connection_data['host'],
            connection_data['dbname']
        )

        self.engine = create_engine(connection_string)
        Base.metadata.bind = self.engine

    def list(self, filters=None):
        DBSession = sessionmaker(bind=self.engine)
        session = DBSession()

        query = session.query(Room)

        if filters is None:
            return query.all()

        if 'code__eq' in filters:
            query = query.filter(Room.code == filters['code__eq'])

        if 'price__eq' in filters:
            query = query.filter(Room.price == filters['price__eq'])

        if 'price__lt' in filters:
            query = query.filter(Room.price < filters['price__lt'])

        if 'price__gt' in filters:
            query = query.filter(Room.price > filters['price__gt'])

        return [
            room.Room(
                code=q.code,
                size=q.size,
                price=q.price,
                latitude=q.latitude,
                longitude=q.longitude
            )
            for q in query.all()
        ]
```

I opted for a very simple solution with multiple `if` statements, but if this was a real world project the `list` method would require a smarter solution to manage a richer set of filters. This class is a good starting point, however, as it passes the whole tests suite. Note that the `list` method returns domain models, which is allowed as the repository is implemented in one of the outer layers of the architecture.

### Running the web server

Now that the whole test suite passes we can run the Flask web server using a PostgreSQL container. This is not yet a production setup, as the Flask web server cannot really sustain big loads, but it shows you the final configuration of the whole architecture.  

First run PostgreSQL in Docker manually

``` sh
docker run --name rentomatic -e POSTGRES_PASSWORD=rentomaticdb -p 5432:5432 -d postgres
```

<!-- ``` sh
docker run -it --rm --link rentomatic:rentomatic postgres psql -h rentomatic -U postgres
Password for user postgres: 
psql (11.1 (Debian 11.1-1.pgdg90+1))
Type "help" for help.

postgres=# 
```
 -->
The password is the one set when Docker is run.

``` sh
$ python initial_postgres_setup.py
```

``` sh
$ docker run -it --rm --link rentomatic:rentomatic postgres psql -h rentomatic -U postgres
Password for user postgres: 
psql (11.1 (Debian 11.1-1.pgdg90+1))
Type "help" for help.

postgres=# \c rentomaticdb 
You are now connected to database "rentomaticdb" as user "postgres".
rentomaticdb=# \dt
        List of relations
 Schema | Name | Type  |  Owner   
--------+------+-------+----------
 public | room | table | postgres
(1 row)

rentomaticdb=# select * from room;
 id |                 code                 | size | price |  longitude  |  latitude   
----+--------------------------------------+------+-------+-------------+-------------
  1 | f853578c-fc0f-4e65-81b8-566c5dffa35a |  215 |    39 | -0.09998975 | 51.75436293
  2 | fe2c3195-aeff-487a-a08f-e0bdc0ec6e9a |  405 |    66 |  0.18228006 | 51.74640997
  3 | 913694c6-435a-4366-ba0d-da5334a611b2 |   56 |    60 |  0.27891577 | 51.45994069
  4 | eed76e77-55c1-41ce-985d-ca49bf6c0585 |   93 |    48 |  0.33894476 | 51.39916678
(4 rows)

rentomaticdb=# 
```





TODO Test and redefine `code/rentomatic/rentomatic/app.py`, implement the `postgres_setup.py` file filling the DB. 

## A repository based on MongoDB

Thanks to the flexibility of clean architecture, providing support for multiple storage systems is a breeze. In this section I will implement the `MongoRepo` class that provides an interface towards MongoDB, a well-known NoSQL database. We will follow the same testing strategy we used for PostgreSQL, with a Docker container that runs the database and docker-compose that orchestrates the spin up and tear down of the whole system.

You will quickly understand the benefits of the complex test structure that I created in the previous section. That structure allows me to reuse some of the fixtures now that I want to implement tests for a new storage system.

Let's start defining the `tests/repository/mongodb/conftest.py` file, which contains the following code

``` python
import pymongo
import pytest


def mg_is_responsive(ip, docker_setup):
    try:
        client = pymongo.MongoClient(
            host=docker_setup['mongo']['host'],
            username=docker_setup['mongo']['user'],
            password=docker_setup['mongo']['password'],
            authSource='admin'
        )
        client.admin.command('ismaster')
        return True
    except pymongo.errors.ServerSelectionTimeoutError:
        return False


@pytest.fixture(scope='session')
def mg_client(docker_ip, docker_services, docker_setup):
    docker_services.wait_until_responsive(
        timeout=30.0, pause=0.1,
        check=lambda: mg_is_responsive(docker_ip, docker_setup)
    )

    client = pymongo.MongoClient(
        host=docker_setup['mongo']['host'],
        username=docker_setup['mongo']['user'],
        password=docker_setup['mongo']['password'],
        authSource='admin'
    )

    yield client

    client.close()


@pytest.fixture(scope='session')
def mg_database_empty(mg_client, docker_setup):
    db = mg_client[docker_setup['mongo']['dbname']]

    yield db

    mg_client.drop_database(docker_setup['mongo']['dbname'])


@pytest.fixture(scope='function')
def mg_data():
    return [
        {
            'code': 'f853578c-fc0f-4e65-81b8-566c5dffa35a',
            'size': 215,
            'price': 39,
            'longitude': -0.09998975,
            'latitude': 51.75436293,
        },
        {
            'code': 'fe2c3195-aeff-487a-a08f-e0bdc0ec6e9a',
            'size': 405,
            'price': 66,
            'longitude': 0.18228006,
            'latitude': 51.74640997,
        },
        {
            'code': '913694c6-435a-4366-ba0d-da5334a611b2',
            'size': 56,
            'price': 60,
            'longitude': 0.27891577,
            'latitude': 51.45994069,
        },
        {
            'code': 'eed76e77-55c1-41ce-985d-ca49bf6c0585',
            'size': 93,
            'price': 48,
            'longitude': 0.33894476,
            'latitude': 51.39916678,
        }
    ]


@pytest.fixture(scope='function')
def mg_database(mg_database_empty, mg_data):
    collection = mg_database_empty.rooms

    collection.insert_many(mg_data)

    yield mg_database_empty

    collection.delete_many({})
```

As you can see these functions are very similar to the ones that we defined for Postgres. The `mg_is_responsive` function is tasked with monitoring the MondoDB container and return True when this latter is ready. The specific way to do this is different from the one employed for PostgreSQL, as these are solutions tailored to the specific technology. The `mg_client` function is similar to the `pg_engine` developed for PostgreSQL, and the same happens for `mg_database_empty`, `mg_data`, and `mg_database`. While the SQLAlchemy package works through a session, PyMongo library creates a client and uses it directly, but the overall structure is the same.

We need to change the `tests/repository/conftest.py` to add the configuration of the MongoDB container. Unfortunately, due to a limitation of the `pytest-docker` package it is impossible to define multiple versions of `docker_compose_file`, so we need to add the MongoDB configuration alongside the PostgreSQL one. The `docker_setup` fixture becomes

``` python
@pytest.fixture(scope='session')
def docker_setup(docker_ip):
    return {
        'mongo': {
            'dbname': 'rentomaticdb',
            'user': 'root',
            'password': 'rentomaticdb',
            'host': docker_ip
        },
        'postgres': {
            'dbname': 'rentomaticdb',
            'user': 'postgres',
            'password': 'rentomaticdb',
            'host': docker_ip
        }
    }
```

While the new version of the `docker_compose_file` fixture is

``` python
@pytest.fixture(scope='session')
def docker_compose_file(docker_tmpfile, docker_setup):
    content = {
        'version': '3.1',
        'services': {
            'postgresql': {
                'restart': 'always',
                'image': 'postgres',
                'ports': ["5432:5432"],
                'environment': [
                    'POSTGRES_PASSWORD={}'.format(
                        docker_setup['postgres']['password']
                    )
                ]
            },
            'mongo': {
                'restart': 'always',
                'image': 'mongo',
                'ports': ["27017:27017"],
                'environment': [
                    'MONGO_INITDB_ROOT_USERNAME={}'.format(
                        docker_setup['mongo']['user']
                    ),
                    'MONGO_INITDB_ROOT_PASSWORD={}'.format(
                        docker_setup['mongo']['password']
                    )
                ]
            }
        }
    }

    f = os.fdopen(docker_tmpfile[0], 'w')
    f.write(yaml.dump(content))
    f.close()

    return docker_tmpfile[1]
```

As you can see setting up MongoDB is not that different from PostgreSQL. Both systems are databases, and the way you connect to them is similar, at least in a testing environment, where you don't need specific settings for the engine.

With the above fixtures we can write the `MongoRepo` class following TDD. The `tests/repository/mongodb/test_mongorepo.py` file contains all the tests for this class

``` python
import pytest
from rentomatic.repository import mongorepo

pytestmark = pytest.mark.integration


def test_repository_list_without_parameters(docker_setup, mg_data, mg_database):
    repo = mongorepo.MongoRepo(docker_setup['mongo'])

    repo_rooms = repo.list()

    assert set([r.code for r in repo_rooms]) == \
        set([r['code'] for r in mg_data])


def test_repository_list_with_code_equal_filter(
        docker_setup, mg_data, mg_database):
    repo = mongorepo.MongoRepo(docker_setup['mongo'])

    repo_rooms = repo.list(
        filters={'code__eq': 'fe2c3195-aeff-487a-a08f-e0bdc0ec6e9a'}
    )

    assert len(repo_rooms) == 1
    assert repo_rooms[0].code == 'fe2c3195-aeff-487a-a08f-e0bdc0ec6e9a'


def test_repository_list_with_price_equal_filter(
        docker_setup, mg_data, mg_database):
    repo = mongorepo.MongoRepo(docker_setup['mongo'])

    repo_rooms = repo.list(
        filters={'price__eq': 60}
    )

    assert len(repo_rooms) == 1
    assert repo_rooms[0].code == '913694c6-435a-4366-ba0d-da5334a611b2'


def test_repository_list_with_price_less_than_filter(
        docker_setup, mg_data, mg_database):
    repo = mongorepo.MongoRepo(docker_setup['mongo'])

    repo_rooms = repo.list(
        filters={'price__lt': 60}
    )

    assert len(repo_rooms) == 2
    assert set([r.code for r in repo_rooms]) ==\
        {
            'f853578c-fc0f-4e65-81b8-566c5dffa35a',
            'eed76e77-55c1-41ce-985d-ca49bf6c0585'
    }


def test_repository_list_with_price_greater_than_filter(
        docker_setup, mg_data, mg_database):
    repo = mongorepo.MongoRepo(docker_setup['mongo'])

    repo_rooms = repo.list(
        filters={'price__gt': 48}
    )

    assert len(repo_rooms) == 2
    assert set([r.code for r in repo_rooms]) ==\
        {
            '913694c6-435a-4366-ba0d-da5334a611b2',
            'fe2c3195-aeff-487a-a08f-e0bdc0ec6e9a'
    }


def test_repository_list_with_price_between_filter(
        docker_setup, mg_data, mg_database):
    repo = mongorepo.MongoRepo(docker_setup['mongo'])

    repo_rooms = repo.list(
        filters={
            'price__lt': 66,
            'price__gt': 48
        }
    )

    assert len(repo_rooms) == 1
    assert repo_rooms[0].code == '913694c6-435a-4366-ba0d-da5334a611b2'
```

These tests obviously mirror the tests written for Postgres, as the Mongo interface has to provide the very same API. Actually, since the initialization of the `MongoRepo` class doesn't differ from the initialization of the `PostgresRepo` one, the test suite is exactly the same.

The `MongoRepo` class is obviously not the same as the Postgres interface, as the PyMongo library is different from SQLAlchemy, and the structure of a NoSQL database differs from the one of a relational one. The file `rentomatic/repository/mongorepo.py` is

``` python
import pymongo

from rentomatic.domain.room import Room


class MongoRepo:
    def __init__(self, connection_data):
        client = pymongo.MongoClient(
            host=connection_data['host'],
            username=connection_data['user'],
            password=connection_data['password'],
            authSource='admin'
        )

        self.db = client[connection_data['dbname']]

    def list(self, filters=None):
        collection = self.db.rooms

        if filters is None:
            result = collection.find()
        else:
            mongo_filter = {}
            for key, value in filters.items():
                key, operator = key.split('__')

                filter_value = mongo_filter.get(key, {})
                filter_value['${}'.format(operator)] = value
                mongo_filter[key] = filter_value

            result = collection.find(mongo_filter)

        return [Room.from_dict(d) for d in result]
```

which makes use of the similarity between the filter system of the Rent-o-matic project and the aggregation TODO framework of the MongoDB system.

