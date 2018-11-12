# Database repositories

The basic in-memory repository I implemented for the project is enough to show the concept of the repository layer abstraction, as any other type of repository will follow the same idea. In the spirit of providing a simple but realistic solution, however, I believe it is worth reimplementing the repository layer with a proper database.

This gives me the chance to show you one of the big advantages of a clean architecture, namely the simplicity with which you can replace existing components with others, possibly based on a completely different technology.

## A repository with a SQL database

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

A repository based on a proper database will not need the data, its main job being that of storing it between sessions, but will nevertheless need to be initialised at least with the database address and access credentials. 