The `pytest-docker` plugin requires you to create a `docker_compose_file` fixture that should return the path of a file with the docker-compose configuration (YAML syntax). The plugin provides two fixtures `docker_ip` and `docker_services`: the first one is simply the IP of the docker host (which can be different from localhost in case of remote execution) while the second is the actual routine that runs the containers through docker-compose and stops them after the test session. My setup to run this plugin is complex, but it allows me to keep all the database information in a single place.

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
