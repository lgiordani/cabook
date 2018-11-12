# Pydemic: a boardgame implemented with gaudi

The game we are going to develop is called PyDemic, and it is a Python version of the beautiful Pandemic game by Matt Leacock. I will create the main engine, without discussing any external interface like Web clients, graphics and so on, as these topics are outside the scope of this book.

You can find the Pandemic rules on the Z-Man Games site, and many videos and tutorials that show you how the game works. I will assume knowledge of the game, and I will not explain the rules but when it will be needed to discuss implementation problems.

The full project is available at TODO

# The board model

Let's start implementing the domain model to represent the board. I will work with two files, one for the tests (`tests/domain/test_board.py`) and one for the code (`pydemic/domain/board.py`).

The board in PyDemic has many attributes: the number of outbreaks, the infection rate, a dictionary representing the current infection of each city, a list containing the position of the research centres, a list of the cured diseases, and a flag that signals if the Quiet Night event is active. All these attributes need a default value.

The current infection is a dictionary because each city, if infected, can contain more than one disease. A possible value for that dictionary is

``` python
infection = {
    'Sydney': {
        constants.COLOUR_BLUE: 2,
        constants.COLOUR_YELLOW: 1
    },
    'London': {
        constants.COLOUR_BLUE: 1,
    }
}
```

which tells us that Sydney has been infected with 2 cubes of the blue disease and 1 of the yellow one, while London has been infected with one cube of the blue disease. All other cities are clean.

As for the actions, the board can have zero to many active events each turn, so we need a way to store and to discard them. It also needs a way to increase the number of outbreaks and to stop the game if they reach the maximum. Last, it needs a way to manage the infection of a city, and this has to implement the outbreaks with the possible chain reaction in the neighbour cities.

Starting from the attributes we have to check that the model accepts the ones listed above, with sensible defaults. The test is

``` python
from gaudi.test_helpers import model_tests

from pydemic import constants
from pydemic.domain import board


test_board_model_init = model_tests.create_model_init_tests(
    board.Board,
    {
        'outbreaks': 2,
        'infection_rate': 2,
        'infection': {
            'Sydney': {
                constants.COLOUR_BLUE: 2,
                constants.COLOUR_YELLOW: 1
            }
        }
    },
    {
        '__defaults': {
            'outbreaks': 0,
            'infection_rate': 0,
            'infection': {},
            'research_centres': [],
            'cured': [],
            'quiet_night': False
        }
    }
)
```

and the code uses the `gaudi.domain.model.Model` class[^dataclasses]

``` python
from gaudi.domain import model


class Board(model.Model):
    attributes = [
        {
            'name': 'outbreaks',
            'default': 0
        },
        {
            'name': 'infection_rate',
            'default': 0
        },
        {
            'name': 'infection',
            'default': dict
        },
        {
            'name': 'research_centres',
            'default': list
        },
        {
            'name': 'cured',
            'default': list
        },
        {
            'name': 'quiet_night',
            'default': False
        }
    ]
```

[^dataclasses]: dataclasses may be the official way to do this in the future, but for now they are available in Python 3.7 only. This shows however that `gaudi` tries to provide classes that can be replaced by custom solutions at any time.

The test relies on a `pydemic/constants.py` file that shall contain the following code

``` python
COLOUR_BLUE = 'COLOUR_BLUE'
COLOUR_RED = 'COLOUR_RED'
COLOUR_BLACK = 'COLOUR_BLACK'
COLOUR_YELLOW = 'COLOUR_YELLOW'
```

I consider worth having tests for the model even if it its structure is generated automatically. Later you might need or want to change the way the model is created, either changing the parameters or dropping the `Model` provided by `gaudi` and implementing it with a different solution. In that case the tests are still checking that your model behaves like intended.

Please note that the tests created with this factory are verbose and tell you the parameters that were used

{line-numbers=off}
``` sh
$ py.test -svv

[...]

tests/domain/test_board.py::test_board_model_init[Args: {'outbreaks': 2, 'infection_rate': 2, 'infection': {'Sydney': {'COLOUR_BLUE': 2, 'COLOUR_YELLOW': 1}}}] <- ../gaudi/gaudi/test_helpers/model_tests.py PASSED
tests/domain/test_board.py::test_board_model_init[Args: {'__defaults': {'outbreaks': 0, 'infection_rate': 0, 'infection': {}, 'research_centres': [], 'cured': [], 'quiet_night': False}}] <- ../gaudi/gaudi/test_helpers/model_tests.py PASSED
```

This set of tests is not exhaustive of all the possible combinations of inputs. I don't consider such a broad range of combinations worth testing, at least until I discover some issue in the code with further tests. It is worth mentioning, however, that with `gaudi` it is very simple to set up initialisation tests for standard models, requiring only a dictionary of the input parameters.

# Managing events

According to the requirements, the `Board` model needs a method to set the active event card so the test for this is

``` python
def test_board_set_active_event():
    b = board.Board()
    b.set_active_event('event1')

    assert b.get_active_events() == ['event1']
```

As you can see this is a standard test, and the two functions `set_active_event` and `get_active_events` are standard methods of a Python class. To store the events I defined a `self._active_events` list in the `__init__` method. Please note that if the class inherits from `gaudi.domain.model.Model` this method has to accept `**kwargs`

``` python
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self._active_events = []

    def set_active_event(self, event):
        self._active_events.append(event)

    def get_active_events(self):
        return self._active_events
```

Since events last for one turn only, there should be a function that pops them from the list. The test is

``` python
def test_board_reset_active_events():
    b = board.Board()
    b.set_active_event('event1')
    b.set_active_event('event2')

    events = b.reset_active_events()
    assert events == ['event1', 'event2']
    assert len(b.get_active_events()) == 0
```

and the code in the class

``` python
    def reset_active_events(self):
        events = self._active_events[:]
        self._active_events = []
        return events
```

# Outbreaks

The board needs a method to record an outbreak event. The test is

``` python
def test_board_increase_outbreak():
    b = board.Board()

    b.outbreak()

    assert b.outbreaks == 1
```

but this method should also check if we reached the maximum number of outbreaks, in which case the game terminates. The test for this behaviour is

``` python
def test_board_increase_outbreak_over_maximum():
    b = board.Board(outbreaks=constants.MAX_OUTBREAKS - 1)

    with pytest.raises(board.GameOver):
        b.outbreak()
```

Remember to import `pytest` at the beginning of the file to make this test work. I decided to signal the end of the game with a `GameOver` exception, which has to be defined

``` python
class GameOver(ValueError):
    pass
```

and an `outbreak` method in the `Board` model

``` python
    def outbreak(self):
        self.outbreaks += 1

        if self.outbreaks == constants.MAX_OUTBREAKS:
            raise GameOver
```

This method uses the `constants` file created before, that you have to import. You also need to add in that file the following line

``` python
MAX_OUTBREAKS = 8
```

# Infections

The infection mechanism in PyDemic is not complex, but it has a lot of corner cases, which translates in a big amount of tests. My recommendation is that you copy the tests one by one, trying to write code that passes the whole test suite, moving to the next test only when everything works. I won't comment here the tests line by line as I consider them very straightforward, I will just mention briefly the purpose of each of them.

The first test is a plain infection of a previously clean city

``` python
def test_board_infect_city():
    b = board.Board()

    b.infect('London', constants.COLOUR_BLUE)

    assert b.infection == {
        'London': {
            constants.COLOUR_BLUE: 1
        }
    }
```

The second test infects a city that is already infected, but without crossing the outbreak threshold of 3

``` python
def test_board_infect_already_infected_city():
    b = board.Board(
        infection={
            'London': {
                constants.COLOUR_BLUE: 2,
                constants.COLOUR_YELLOW: 1
            }
        }
    )

    b.infect('London', constants.COLOUR_BLUE)

    assert b.infection == {
        'London': {
            constants.COLOUR_BLUE: 3,
            constants.COLOUR_YELLOW: 1
        }
    }
```

This test infects a city which is already on the brink of an outbreak and verifies that the outbreak happens

``` python
def test_board_infect_city_outbreak_increases_outbreaks():
    b = board.Board(
        infection={
            'London': {
                constants.COLOUR_BLUE: 3,
                constants.COLOUR_YELLOW: 1
            }
        }
    )

    b.infect('London', constants.COLOUR_BLUE)

    assert b.outbreaks == 1
```

Next, we test that infecting a city and making an outbreak happen can terminate the game if the number of outbreaks is already too high

``` python
def test_board_infect_city_too_many_outbreaks():
    b = board.Board(
        infection={
            'London': {
                constants.COLOUR_BLUE: 3,
                constants.COLOUR_YELLOW: 1
            }
        },
        outbreaks=constants.MAX_OUTBREAKS - 1
    )

    with pytest.raises(board.GameOver):
        b.infect('London', constants.COLOUR_BLUE)
```

This test verifies that the outbreak in a city has effect on the cities that are directly connected to it

``` python
def test_board_infect_city_outbreak():
    b = board.Board(
        infection={
            'London': {
                constants.COLOUR_BLUE: 3
            }
        }
    )

    b.infect('London', constants.COLOUR_BLUE)

    assert b.outbreaks == 1
    assert b.infection == {
        'London': {
            constants.COLOUR_BLUE: 3,
        },
        'New York': {
            constants.COLOUR_BLUE: 1,
        },
        'Madrid': {
            constants.COLOUR_BLUE: 1,
        },
        'Paris': {
            constants.COLOUR_BLUE: 1,
        },
        'Essen': {
            constants.COLOUR_BLUE: 1,
        }
    }
```

The final test checks that the chain of reaction doesn't loop, i.e. a city cannot be hit twice in the same turn by the same outbreak.

``` python
def test_board_infect_city_outbreak_does_not_apply_twice():
    b = board.Board(
        infection={
            'London': {
                constants.COLOUR_BLUE: 3
            },
            'Essen': {
                constants.COLOUR_BLUE: 3
            }
        }
    )

    b.infect('London', constants.COLOUR_BLUE)

    assert b.outbreaks == 2
    assert b.infection == {
        'London': {
            constants.COLOUR_BLUE: 3,
        },
        'New York': {
            constants.COLOUR_BLUE: 1,
        },
        'Madrid': {
            constants.COLOUR_BLUE: 1,
        },
        'Paris': {
            constants.COLOUR_BLUE: 2,
        },
        'Essen': {
            constants.COLOUR_BLUE: 3,
        },
        'Milan': {
            constants.COLOUR_BLUE: 1,
        },
        'St. Petersburg': {
            constants.COLOUR_BLUE: 1,
        }
    }
```

My solution for the `Board` model is the following

``` python
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self._tmp_outbreaks = []
        self._active_events = []

    def _infect(self, city, colour):
        city_infection = self.infection.setdefault(city, {})
        current_infection = city_infection.setdefault(colour, 0)

        if current_infection != constants.MAX_INFECTION:
            city_infection[colour] = city_infection[colour] + 1
            return

        if (city, colour) in self._tmp_outbreaks:
            return

        self._tmp_outbreaks.append((city, colour))
        self.outbreak()

        for neighbour in constants.CONNECTIONS[city]:
            self._infect(neighbour, colour)

    def infect(self, city, colour):
        self._infect(city, colour)
        self._tmp_outbreaks = []
```

Note that I changed the definition of `__init__` to have a helper `__tmp outbreaks` variable, and that I defined a recursive function `_infect` that manages the chain reaction. The `constants` file requires now `MAX_INFECTIONS` set to 3 and a `CONNECTIONS` dictionary that represents the links between cities.

``` python
MAX_INFECTION = 3

CONNECTIONS = {
    'Algiers': ['Madrid', 'Paris', 'Istanbul', 'Cairo'],
    'Atlanta': ['Chicago', 'Washington', 'Miami'],
    'Baghdad': [
        'Istanbul', 'Tehran', 'Karachi', 'Riyadh', 'Khartoum', 'Algiers'
    ],
    [...]
```

# Other models

The remaining two models we need are `Deck` and `Player`.

`Deck` is used to represent a generic deck of cards, and shall provide enough methods to interact with the decks used in the game and with the relative discard decks. In particular the model I created has a single attribute `cards` and four methods: `draw_top`, `draw_bottom`, `add_bottom`, and `add_top`.

The `Player` model has many attributes and a single method. The attributes are `name`, `role`, `city`, `hand`, and `single_use`. The `hand` attribute represents the city cards that the player has at at a certain time, and `single_use` represents the event cards. I decided to keep them separate but since cards have a type these two lists may be merges in one.

# Use cases

When you define a use case you can store it in `gaudi`. The library keeps a global register of use cases and thus you can use `UseCaseRegister`, `UseCaseCreator`, or `UseCaseExecutor`.

The `UseCaseExecutor` class in particular is available as a fixture in `gaudi.test_helpers.fixtures.use_case_executor` so our `tests/conftest.py` can import it and make it available to all our tests

``` python
from gaudi.test_helpers import fixtures

uce = fixtures.use_case_executor
```

Let's start discussing use cases with a simple example, `BoardInitUseCase`. This use case shall initialise a `Board` and return it in the response. 

``` python
from pydemic import constants


def test_board_init(uce):
    infection = {
        'Sydney': {
            constants.COLOUR_BLUE: 2,
            constants.COLOUR_YELLOW: 1
        }
    }

    res = uce.BoardInitUseCase({
        'outbreaks': 2,
        'infection_rate': 2,
        'infection': infection,
    })

    assert bool(res) is True
    assert res.content['board'].outbreaks == 2
    assert res.content['board'].infection_rate == 2
    assert res.content['board'].infection == infection
```

As you can see the main part of the test is played by `uce.BoardInitUseCase`, which is called with some parameters. Under the hood, this is initialising the registered `BoardInitUseCase` class and running its `execute` method. The test is straightforward, the use case is called with some parameters and the response is checked with `assert` statements.

The definition of `BoardInitUseCase` goes in the file `use_cases/board/board_init.py`

``` python
from gaudi.use_cases import use_case as uc
from gaudi import response_object as res

from pydemic.domain import board


class BoardInitUseCase(uc.UseCase):
    parameters = [
        {
            'name': 'outbreaks',
            'default': 0
        },
        {
            'name': 'infection_rate',
            'default': 0
        },
        {
            'name': 'infection',
            'default': {}
        },
    ]

    def process_request(self, request):
        b = board.Board(
            outbreaks=request['outbreaks'],
            infection_rate=request['infection_rate'],
            infection=request['infection'],
        )

        r = res.ResponseSuccess.create_default_success({
            'board': b
        })

        return r
```

Under the hood `gaudi` uses the use case `parameters` class attribute to validate the request. The `process_request` method is used to run the actual use case logic, and it is fired only if the request is valid. This means that you can access the request fields without checks.

To return a successful response I use `gaudi.response_object.ResponseSuccess.create_default_success` passing the board that was just created.

I defined 5 use cases for the board model, each one with specific tests and code kept in separate files. While this is not required, it might be a good way to keep the structure of the project clean and tidy. The use cases I defined, apart from `BoardInitUseCase`, are `BoardCreateResearchCentre`, `BoardFinishQuietNight`, `BoardIncreaseRate`, and `BoardInfectCity`.

This last one is a good example of rich use case that can return either successful or unsuccessful responses. The code is

``` python
from gaudi.use_cases import use_case as uc
from gaudi import response_object as res

from pydemic import constants
from pydemic import responses
from pydemic.domain import board


class BoardInfectCityUseCase(uc.UseCase):
    parameters = [
        'board',
        'city',
        'colour',
        {
            'name': 'players',
            'default': []
        }
    ]

    def process_request(self, request):
        b = request['board']
        city = request['city']
        colour = request['colour']

        roles_in_city = [p.role for p in request['players'] if p.city == city]

        roles_in_near_cities = [
            p.role for p in request['players']
            if p.city in constants.CONNECTIONS[city]
        ]

        if constants.ROLE_QUARANTINE_SPECIALIST in \
                roles_in_city + roles_in_near_cities:
            return res.ResponseSuccess.create_default_success({
                'board': b,
            })

        if constants.ROLE_MEDIC in roles_in_city and colour in b.cured:
            return res.ResponseSuccess.create_default_success({
                'board': b,
            })

        try:
            b.infect(city, colour)
        except board.GameOver:
            return res.ResponseFailure.create(
                responses.GAME_OVER_ERROR, 'Outbreak')

        return res.ResponseSuccess.create_default_success({
            'board': b,
        })
```

This use case is run when a city gets infected during the relative phase. The standard case is that the city gets infected and is returned with a `ResponseSuccess`. The `infect` method of the `Board` class already takes care of the outbreaks, but if there are too many of them the method raises the `board.GameOver` exception. In that case we return a `ResponseFailure` of type `responses.GAME_OVER_ERROR`.

There are two cases in which the infection doesn't happen, namely when a Medic is in the city and the disease has been cured, and when a Quarantine Specialist is either in the city or in a nearby city (directly connected). Both this cases are handles by a simple if condition and return a `ResponseSuccess`.


