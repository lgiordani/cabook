TODO(the code changed, the name of the fixtures changed)


# Chapter 4 - Database repositories

The basic in-memory repository I implemented for the project is enough to show the concept of the repository layer abstraction, as any other type of repository will follow the same idea. In the spirit of providing a simple but realistic solution, however, I believe it is worth reimplementing the repository layer with a proper database.

This gives me the chance to show you one of the big advantages of a clean architecture, namely the simplicity with which you can replace existing components with others, possibly based on a completely different technology.

## Introduction

The clean architecture we devised in the previous chapters defines a use case that receives a repository instance as an argument and uses its `list` method to retrieve the contained entries. This allows the use case to form a very loose coupling with the repository, being connected only through the API exposed by the object and not to the real implementation. In other words, the use cases are polymorphic in respect of the `list` method.

This is very important and it is the core of the clean architecture design. Being connected through an API, the use case and the repository can be replaced by different implementations at any time, given that the new implementation provides the requested API.

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

Furthermore, we have to deal with a proper external system, so we need to devise a way to test the repository without the need of a running database engine in the background. Remember that we are creating a specific implementation of a repository, so everything will be tailored to the actual database system that we will choose.

## A repository based on Postgres

Let's start with a repository based on a popular SQL database, PostgreSQL[^postgresql]. It can be accessed from Python in many ways, but probably the best is through the SQLAlchemy[^sqlalchemy] interface. SQLAlchemy is an ORM, a package that maps objects (as in object-oriented) to a relational database, and can normally be found in web frameworks like Django or in standalone packages like this.

[^postgresql]: https://www.postgresql.org
[^sqlalchemy]: https://www.sqlalchemy.org

The important thing about ORMs is that they are very good example of somethign you shouldn't try to mock. Properly mocking the SQLAlchemy structures that are used when querying the DB results in very complex code that is difficult to write and almost impossible to maintain as every single change in the queries results in a series of mocks that have to be written again.[^query]

[^query]: unless you consider things like `sessionmaker_mock()().query.assert_called_with(Room)` something attractive, in which case I highly recommed undertaking TODO(?) this journey. And this was by far the simplest mock I had to write.

We need therefore to set up an integration test. The idea is to create the DB, set up the connection with SQLAlchemy, test the condition we need to check, and destroy the database. Since the action of creating and destroying the DB can be expensive in terms of time we might want to try to it just at the beginning and at the end of the test suite, but even with this change the tests will be slow. This is why we will also need to label them and to avoid running them every time we run the whole suite.

### Label integration tests

The first thing we need to do is to label integration tests, exclude them by default and create a way to run them. Since pytest support labels, called _marks_ we can use this feature adding a global mark to a whole module. Create the `tests/repository/test_postgresrepo.py` file and put in it this code

``` python

import pytest

pytestmark = pytest.mark.integration


def test_dummy():
    pass
```

The `pytestmark` module attribute labels every test in the module with the "integration" tag. To verify that this works I added a `test_dummy` test function which passes always. You can run `py.test -svv -m integration` now to ask pytest to run only the tests marked with that label. The `-m` option supports a rich syntax that you can learn reading the documentation [^pytestmarks]

[^pytestmarks]: https://docs.pytest.org/en/latest/example/markers.html

While this is enough to run integration tests selectively, it is not enough to skip them by default. To do this we can alter the pytest setup to label all those tests as skipped, but this will give us no means to run them. The pattern many pytest users follow it that of defining a new command line option and to mark those tests as skipped only if they are marked and the command line option is not present.

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

Add the packages `SQLAlchemy` to the `prod.txt` requirements file and update the installed packages with

``` sh
$ pip install -r requirements/dev.txt
```

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

This is the class that represents the `Room` in the database. It is important to understand that this not the class we are using in the business logic, but the class that we want to map in the SQL database. The structure of this class is thus dictated by the needs of the storage layer, and not by the use cases. You might want to store `longitude` and `latitude` in a JSON field, for example, to allow for easier extendibility, of for other reasons, without changing the definition of the domain model. In the simple case of the Rent-o-matic project the two classes overlap, but this is not the case generally speaking.

Obviously this means that you have to keep in sync the storage level with the domain one, and that you need to manage migrations on your own. You can obviously use tools like Alembic, but the migrations will not come directly from domain model changes. My experience with migrations is that in big production systems is almost always better to separate the two layers, so personally the clean architecture's approach doesn't look like a big sacrifice.

### Setup and tear down the integration suite

When we run the integration tests the Postgres database engine must be already running in background, and it must be already configured, for example with a pristine database ready to be used. Moreover, when all the tests have been executed the database should be removed and the database engine stopped.

This is a perfect job for Docker, which can run complex systems in isolation with minimal configuration. We might orchestrate the creation and destruction of the database with bash, but this would mean wrapping the test suite in another script which is not my favourite choice.

The structure that I show you here makes use of docker-compose through the `pytest-docker`, `pyyaml`, and `sqlalchemy-utils` packages. The idea is simple: given the configuration of the database (name, user, password), we create a temporary file containing the docker-compose configuration that spins up a Postgres database. We connect to the database engine with SQLAlchemy to create the database we will use for the tests and we populate it. When all the tests have been run we tear down the Docker image and we leave the system in a clean status.

To perform all that I said I will make use of many fixtures with `scope='session'` TODO

The first fixture I defined in `tests/conftest.py` contains the information about the PostgreSQL connection, namely the database name, the user name, and the password

``` python
@pytest.fixture(scope='session')
def pg_setup(docker_ip):
    return {
        'dbname': 'rentomaticdb',
        'user': 'postgres',
        'password': 'rentomaticdb',
        'host': docker_ip
    }
```

This way I have a single source of parameters for the connection. If you prefer to store those values in a file you can obviously change the fixture to load it instead of using a dictionary.

The second piece of code is not a fixture, but a function that will be used by the docker-compose system to decide if the Postgres container is up and running. Containers take a certain amount of time to become responsive, partly because of the Docker infrastructure itself (possibly downloading the image, running the container, setting up the network, and so on), and partly because of the software they run (in this case the PostgreSQL engine) that needs to be initialised. The `is_responsive` function receives the IP of the container, decided by Docker, and the Postgres connection data.

``` python
def is_responsive(ip, pg_setup):
    try:
        conn = psycopg2.connect(
            "host={} user={} password={} dbname={}".format(
                ip,
                pg_setup['user'],
                pg_setup['password'],
                'postgres'
            )
        )
        conn.close()
        return True
    except psycopg2.OperationalError as exp:
        return False
```

Docker-compose needs a file containing the description of the containers and their links. Even though in this case we have a single container, the requirement is the same. The first fixture creates then a temporary file that is used in the second fixture to host the YAML configuration of the infrastructure

``` python
@pytest.fixture(scope='session')
def tmpfile():
    f = tempfile.mkstemp()
    yield f
    os.remove(f[1])


@pytest.fixture(scope='session')
def docker_compose_file(tmpfile, pg_setup):
    postgres = {
        'postgresql': {
            'restart': 'always',
            'image': 'postgres',
            'ports': ["5432:5432"],
            'environment': [
                'POSTGRES_PASSWORD={}'.format(
                    pg_setup['password']
                )
            ]
        }
    }

    f = os.fdopen(tmpfile[0], 'w')
    f.write(yaml.dump(postgres))
    f.close()

    return tmpfile[1]
```

Now the proper PostgreSQL container can be run through the `docker_services` fixture provided by `pytest-docker`, which in turn uses the `is_responsive` function that we defined before. After the container is up and running we can initialise a SQLAlchemy engine and create the test database with `create_database` provided by `sqlalchemy_utils`. After this we spawn a new connection from the previously created engine and yield the engine itself, closing the connection when the fixture is disposed.

``` python
@pytest.fixture(scope='session')
def pg_engine(docker_ip, docker_services, pg_setup):
    docker_services.wait_until_responsive(
        timeout=30.0, pause=0.1,
        check=lambda: is_responsive(docker_ip, pg_setup)
    )

    conn_str = "postgresql+psycopg2://{}:{}@{}/{}".format(
        pg_setup['user'],
        pg_setup['password'],
        pg_setup['host'],
        pg_setup['dbname']
    )
    engine = sqlalchemy.create_engine(conn_str)
    sqlalchemy_utils.create_database(engine.url)

    conn = engine.connect()

    yield engine

    conn.close()
```

This provides a new connection and a pristine database, but it is still not enough for our tests, as we need to populate the database to run queries against it.

``` python
from rentomatic.repository.postgres_objects import Base, Room

[...]

@pytest.fixture(scope='session')
def pg_session_empty(pg_engine):
    Base.metadata.create_all(pg_engine)

    Base.metadata.bind = pg_engine

    DBSession = sqlalchemy.orm.sessionmaker(bind=pg_engine)

    session = DBSession()

    yield session

    session.close()
```

This new fixture provides access to a SQLAlchemy session on the empty database, if we need it for some tests. Note that we imported `Base` and `Room` that we defined in the `postgres_objects` file

``` python
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

This last fixture inserts some data in the database using the SQLAlchemy `Room` model. Our dummy test can now actually interact with the database and test that the 4 entries have been added to the database

``` python
import pytest
from rentomatic.repository.postgres_objects import Room

pytestmark = pytest.mark.integration


def test_dummy(postgres_data):
    assert len(postgres_data.query(Room).all()) == 4
```

Note that the `postgres_data` fixture has a `function` scope, thus it is run for every test. This is why we delete all rooms at the end of each test, leaving the database in the same state it had before the test. This is not strictly necessary in this particular case, as we are only reading from the database, so we might add the rooms at the beginning of the test session and just destroy the container at the end of it. This doesn't however work in general, for instance when tests add entries to the database, so I preferred to show you a more generic solution.
