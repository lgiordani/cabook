# Chapter 1 - Components of the library

A clean architecture is not a framework in the common sense. From a certain point of view it is the opposite of a framework, as it pushes a structure that is modelled after your application and not the opposite. This doesn't mean however that everything has to be written from scratch every time.

After I wrote many applications following the clean architecture approach, I realised that many parts of the code that I was writing could be abstracted and isolated, and I started doing it consistently. The result is the [gaudi](https://github.com/lgiordani/gaudi) library, which is an initial attempt to provide helper classes and functions to Python programmers who want to implement a project based on the clean architecture.

The main concern of gaudi is to provide useful abstractions, keeping the compatibility with a custom system that the author may have already created. This means that you can introduce gaudi gradually, and even use it for just some parts of your architecture. You might define the domain models using gaudi's base `Model` class and implement use cases by yourself, or do the opposite, using the `UseCase` class provided by gaudi with your models. You can obviously just discard gaudi at all and implement everything from scratch like we did in the previous chapter.

In this part I will develop a board game engine with a clean architecture using gaudi. This is meant to demonstrate once again how to use a clean architecture in a project, and to show how gaudi can simplify the code.

## Domain models

Gaudi provides the the `Model` class which is used to represent a domain model.

``` python
from gaudi.domain import model


class MyModel(model.Model):
    pass
```

The class can be given some `attributes`, which become the attributes of each instance.

``` python
from gaudi.domain import model


class Item(model.Model):
    attributes = ['price']


u = Item(price=1200)
print(u.price)
```

An attribute can be specified as a simple string or as a dictionary, in which case you have to give it at least a `name` key with the actual attribute name as value.

``` python
from gaudi.domain import model


class Item(model.Model):
    attributes = [
        {
            'name': 'price'
        }
    ]


u = Item(price=1200)
print(u.price)
```

This form comes handy when we want to specify other properties of the attribute. For example you can give it a default

``` python
from gaudi.domain import model


class Item(model.Model):
    attributes = [
        {
            'name': 'price',
            'default': 100
        }
    ]


u = Item(price=1200)
print(u.price)
```

When you redefine the `__init__` method of a Gaudi model you have to make it accept `kwargs`

``` python
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        [your code]
```

All Gaudi model classes expose the `from_mapping` method that instantiates the model with the values contained in a dictionary-like object.

``` python
i = Item.from_mapping({'price': 1200})
```

TODO(what about serializers?)

## Testing models

The models created by Gaudi have a different way to specify the attributes, but apart from that they are standard Python classes, so you can test them with the usual pytest functions

``` python
def test_init_item():
    i = Item(price=200)
    assert i.price == 200
```

Since writing initialisation tests is often boring and repetitive, Gaudi provides a test factory, that is a function that generates tests for you. This is a good way to express tests like the one I showed above without having to write the whole function for each attribute of the model. The factory is `create_model_init_tests` in `gaudi.test_helpers.model_tests`

``` python
from gaudi.test_helpers import model_tests


test_item_model_init = model_tests.create_model_init_tests(
    Item,
    {
        'price': 200
    }
)
```

This code creates a test like the `test_init_item` function shown previously, instantiating the `Item` class with `price=200` and testing that this is true in the instance.

The function accepts multiple test cases, which is useful to test different combinations of input values or to check that some parameters are optional

``` python
from gaudi.test_helpers import model_tests


test_item_model_init = model_tests.create_model_init_tests(
    Item,
    {
        'price': 200
    },
    {
        'price': 200,
        'weight': 340
    }
)
```

In this case the `weight` attribute has to be optional, as the first test doesn't specify it. The resulting test function however is not testing the default value assigned to the attribute. If you want to test those values you have to include a `__defaults` special attribute, which is a dictionary of the expected values

``` python
from gaudi.test_helpers import model_tests


test_item_model_init = model_tests.create_model_init_tests(
    Item,
    {
        'price': 200
    },
    {
        'price': 200,
        'weight': 340
    },
    {
        'price': 200,
        '__defaults': {
            'weight': 10
        }
    }
)
```

This last version, for example, tests that the class can be instantiated with `price=200` and then checks that the value of the `price` attribute is 200 and that the value of `weight` is 10.

By default the `create_model_init_tests` function uses `__init__` to instantiate the model, calling the class directly, but if you want to test another initialization function you can use `create_model_initialisation_tests` specifying `init_function=your_function` when you call it. If you are using Gaudi models you can use `create_model_from_mapping_tests` which uses `from_mapping` instead of `__init__`.

## Use cases

Gaudi's use cases are built on top of the `gaudi.use_cases.use_case.UseCase` class. The use cases system in Gaudi uses both a global register and class attributes to simplify request validation and the business logic execution. The request structure is defined together with the use case, thus it doesn't require an external class, but can be expressed with a simple dictionary.

Response objects are instead implemented as specific objects, defined in `gaudi.response_object`, and they will be described in the next section.

Let's see an example of a use case to initialise an `Item` model

``` python
from gaudi.use_cases import use_case as uc
from gaudi import response_object as res

from myproject.domain import item


class ItemInitUseCase(uc.UseCase):
    parameters = ['price']

    def process_request(self, request):
        i = item.Item(
            price=request['price']
        )

        r = res.ResponseSuccess.create_default_success({
            'item': i
        })

        return r
```

The first lines import the use case, the response object modules, and the specific module that contains the model we want to process in this class. use case classes define a `parameters` attribute just like the model defines `attributes`, with the same syntax. In this case the only parameter accepted by the use case is `price`.

The `parameters` class attribute is used to validate incoming requests, and in this case any request has to contain a `price` key. The `process_request` function is called when the use case is executed and the internal mechanism of the `UseCase` class will check the validity of the request before executing it, returning a failure response if the `price` parameter is not present.

If the `process_request` method is executed we are sure that the request complies with the parameters that we specified in the class. We can then use those parameters in the business logic, in this example to instantiate the `Item` class. The return value of the method has to be a response, in this case an instance of `gaudi.response_object.ResponseSuccess`.

## Responses

Gaudi defines 4 categories of responses out of the box, `DEFAULT_SUCCESS`, `USE_CASE_ERROR`, `PARAMETERS_ERROR`, and `EXCEPTION_ERROR`. The first one is the only category of successful response, while the remaining three are the different categories of failure that we can have.

If the use case receives a wrong request the response will be an instance of `gaudi.response_object.ResponseFailure` with category `PARAMETERS_ERROR`. If the use case raises an exception, either explicitly raised by your code or by some code that you use, the failure response will have the `EXCEPTION_ERROR` category. Last, the `USE_CASE_ERROR` is available to be used when the business logic has an error, for example if you are looking for a result in a database and you don't find anything that satisfies the search criteria. In that case it is up to you to decide if this is part of the business logic or if it is an unrecoverable error, and in this last case you can return a failure with this last category.

The response classes that Gaudi provides expose convenient methods to return responses that belong to the default categories. `ResponseSuccess` has the method `create_default_success` that I used in the above example, while `ResponseFailure` provides `create_use_case_error`, `create_exception_error`, and `create_parameters_error`. You are encouraged to add your error and success categories, and subclass these classes to add convenience methods.

All responses have a content attribute that can carry valuable information for the process that called the use case. Successful responses have to carry the result of the business logic, if any, while failures will contain details on the error.

In particular, `PARAMETERS_ERROR` responses will contain a list of tuples `(parameter_name, explanation)`, like for example `('param1', "is missing")` is the parameter is mandatory and has not been provided, or `('param1', "is undeclared")` if the parameter has not been declared in the `parameters` attribute of the use case class. The `EXCEPTION_ERROR` responses, instead, will contain the exception itself (see the documentation for details on the format of these responses).

Gaudi use cases accept two arguments `exception_on_failure` and `no_traceback`. The first one is used to store an exception that will be automatically raised in case of failure, overriding any exception that was raised inside the code of the use case. The `no_traceback` argument, instead, changes the way exceptions are returned in the response (again, read the documentation for details on exceptions).

## Registering use cases

Gaudi use cases are registered when they are imported, so the easiest thing to do is to import them in the `__init__.py` file of your module. This is not strictly compliant with PEP8, as you import them without using them, but it allows you to use the powerful `UseCaseRegister`, `UseCaseCreator`, and `UseCaseExecutor` objects.

All these classes are defined in `gaudi.use_cases.use_case` together with `UseCase`. The first provides access to the registered classes through a dotted notation

``` python
from gaudi.use_cases.use_case import UseCaseRegister
from myproject.use_cases import ItemInitUseCase


use_case_class = UseCaseRegister().ItemInitUseCase
```

The `UseCaseCreator` class gives a dotted notation access to instances of the requested use cases. Not that instances are created on the fly, they are not cached anywhere. This class is initialised with parameters that are passed to every use case it will instantiate, so it is a convenient way to set a configuration values for use cases.

``` python
from gaudi.use_cases.use_case import UseCaseCreator
from myproject.use_cases import ItemInitUseCase


creator = UseCaseCreator(exception_on_failure=ValueError)
use_case_instance = creator.ItemInitUseCase
```

The above example instantiates the `UseCaseCreator` class passing `exception_on_failure=ValueError`. Every use case instantiated by this creator will then receive the same parameter.

The last class provided to manage registered use cases is `UseCaseExecutor`. This class is a subclass of `UseCaseCreator` that returns directly the `execute` method of the use case instead of the instance. This allows to call use cases in a compact way with a dotted notation.

``` python
from gaudi.use_cases.use_case import UseCaseExecutor
from myproject.use_cases import ItemInitUseCase


executor = UseCaseExecutor(exception_on_failure=ValueError)
request = {...}
response = executor.ItemInitUseCase(request)
```

## Specialised use cases

Gaudi provides some specialised use cases that may be handy in standard situations. As it happens for other parts of the library, you can completely ignore these use cases if they don't suit your needs, or subclass them to expand their functionalities.

The first use case is `RepositoryUseCase`, contained in `gaudi.use_cases.repository_use_case`. This use case is a subclass of `UseCase` that already contains a `repository` parameter in its definition. This means that every request that reaches the use case has to contain a `repository` key, and that you can access `request['repository']` in the `process_request` method. Since many use cases interact with some external repository, be it the database of some other form of storage/register, this class is a compact way to connect the use case with such components.

Gaudi then provides four use cases that cover standard actions with models, `ModelCreateUseCase`, `ModelGetUseCase`, `ModelListUseCase`, and `ModelDeleteUseCase`. All these use cases are subclasses of `RepositoryUseCase` and require you to specify the `model` class attribute with the class of the model you want them to work with.

## Creating models

The `ModelCreateUseCase` provides a `process_request` method that calls a creation function of the repository passing to it the whole request. The creation function name is derived from the model name, appending `_create` to its lower case name. The response will contain the created object under a key that is the lower case name of the model.

``` python
from gaudi.use_cases.model_create_use_case import ModelCreateUseCase
from myproject.domain.item import Item


class ItemCreateUseCase(ModelCreateUseCase):
    model = Item


repo = MyRepository()
res = ItemCreateUseCase({'repository': repo, 'price': 250})
```

The last line of this example calls `repo.item_create({'price': 250})` and returns a response with an `'item'` key which value is the newly created object.

## Find models

The `ModelGetUseCase` class is very similar to `ModelCreateUseCase`, but it calls the `<model_name>_get` method of the repository. The result has to be unique, otherwise this use case will return a `ResponseFailure` with a use case error. The response contains the requested model under the key `<model_name>`

## Deleting models

`ModelDeleteUseCase` has a similar constraints to `ModelGetUseCase`. It catches a `DeleteMultipleResultsError` exception raised by the repository and returns a user case error. This relies on the repository to provide such an exception in case the given request didn't narrow enough the results. The result of the delete operation is returned under the key `<model_name>`.

## Listing models

The last class provided by Gaudi is `ModelListUseCase`, which accepts a `filters` parameter. The use case calls the `<model_name>_list` method of the repository passing the `filters` parameter as a named argument and returning a response with the results as values of the `<model_name>_list` key.

