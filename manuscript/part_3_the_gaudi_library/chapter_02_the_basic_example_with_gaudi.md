# Chapter 2 - The basic example reimplemented

In this chapter I will reimplement the "Rent-o-matic" project with gaudi. This way you will appreciate the power of the library, having already seen the code that implements the clean architecture from scratch.

You can find the full project code at TODO.

``` python
import uuid

from gaudi.test_helpers import model_tests

from rentomatic_gaudi.domain import room as r


test_room_model_init = model_tests.create_model_init_tests(
    r.Room,
    {
        'code': uuid.uuid4(),
        'size': 200,
        'price': 10,
        'longitude': '-0.09998975',
        'latitude': '51.75436293'
    }
)
```

``` python
from gaudi.domain import model


class Room(model.Model):
    attributes = [
        'code',
        'size',
        'price',
        'longitude',
        'latitude'
    ]
```

