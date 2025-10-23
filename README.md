# Software Engineering project: Data compressing for speed up transmission


### **Arno LESAGE** - *M1 Informatique (2025/2026), spé. IA, EUR DS4H, Université Côte d'Azur, France*


Transmission of integer arrays is part of one of the central problems of the internet. This project aims to implement three different method relying on *Bit Packing* for integer array compression in order to reduce the transmission delay $d_{\text{trans}}$.

More precisely, considering a finite length array of 32-bit encoded integer, we want to compress the contained information knowing that some integer might not require the full 32-bit space to fit in memory. This work is done via three different implementation of *Bit Packing*:

- **Split:** Letting the possibility for a 32-bit integer to be splitted between two 32-bit integer after compression,
- **No Split:** Prohibiting the split of an integer into two different integer after compression,
- **Overflow:** Same as split, but use a threshold to separate integers needing more bits and less bits in order to further optimise memory usage.

***Note:** One constraint apply to all of these methods. The order of the integer must be preserved and accessible even after compression and/or decompression.*

## Getting Started
This part contains instructions to properly set up the project and run it.

### Prerequisites
This project was developped using **Python 1.12.0** (install <a href="https://www.python.org/downloads/release/python-3120/">here</a>) and require the language to run properly.

Additionally, the project make usage of several external libraries (see <a href="OTHERS//requirements.txt">requirements.txt</a>) and therefore require the installation of <a href="https://pip.pypa.io/en/stable/installation/">pip</a> (the Python library manager).

To install the right version of each required library (NumPy, SciPy, PyTest and bitarray), you may use the following command (Windows 10/11):

    pip install -r .\OTHERS\requirements.txt

### Installing

To install the project, download the zipped folder of this repository. Decompress it and open the folder as working directory using any IDE.

You can now use the integer array compression tools by creating a new Python script within the working directory and adding the following header:

```py
from main import BitPacking
mode = ... # between "split", "nosplit" or "overflow"
bP = BitPacking(mode)
```

A typical use example may be the following:
```py
from main import BitPacking
from typing import Any
import numpy as np
import bitarray as b

# Get Array and initialise bit packing
inArr:np.ndarray[int] = np.array([-892, 89, 760, 216, 14], dtype=np.int32)
bP = BitPacking("split")

# Feed with array 
bP.setArr(inArr)
bP.compress()

# Get compressed array
outArr:b.bitarray, *_ = bP.getCompressedArr()
# bitarray('1110111110000001011001010111110000001101100000000001110000000000')

# Decompress array
bP.decompress()
decompressedArr = bP.getArr()
# [-892 89 760 216 14]
```

## Project structure
```txt
C:.
│   arrayGenerator.py
│   benchmark.py
|   benchmarkAnalysis.r
│   main.py
│   README.md
│   tests.py
│
├───Compressor
│   │   AbstractCompressor.py
│   │   NoSplitCompressor.py
│   │   OverflowCompressor.py
│   └───SplitCompressor.py
│
├───img
│       ...
│
├───IN
│       ...
│
├───OTHERS
│       requirements.txt
│
└───OUT
        ...
```

In this tree, `arrayGenerator.py` is responsible for the creation of the input files, `benchmark.py` for the the benchmark, `main.py` for the `BitPacking` class and `tests.py` for the tests.

In `Compressor/`, you will find the implementation for all compressor method (split, nosplit, overflow).

Finally, you will find the input files within `IN/` the output files (benchmark) in `OUT/` and the required libraries in `OTHERS`

## Tests
This part explains the tests performed and how to use them.

### What tests
For the tests, we propose 4 main tests which are then used 15x7 times for each input files and compressor (overflow compressor using multiple thresholds) + 3x7 for special datasets (Dataset with only one value, one zero or only integer on 32 bits.). In total, we test the behaviour of our systsem on 504 independent tests.

- The first main test consists of checking whether the input of the system (uncompressed array) corresponds to the output of the system (decompression after compression). The structure of this test is the following:
```py
import numpy as np
import main

split = main.BitPacking("split")
split.setArr(np.fromfile(f"IN\\{file}", dtype=np.int32, sep=" "))
split.compress()
split.decompress() # decompress change the storred array to the uncompressed one

assert np.all(split.getArr()==testVal) # Check if all value are the same
```
- The other main tests are here to check the integrity of the `main.Bitpacking.get` function. For this purpose, we check if the first value of the uncompressed array corresponds to the value we get from the function at position 0. Then, we do the same with the median value (the middle position) and the last position. If all these values are the same, then the test can be considered passed.

### Run the tests
To run the tests, you just need to open the project directory as working directory, open a terminal and write:
```pwsh
pytest .\tests.py
```
If everything worked well, you should be able to see a picture like this:

<img title="Tests passed succesfully" alt="Oops, the picture did not show" src="img\test_passed.png">

***Note:** Performing the tests would require the python library _PyTest_* 

## Benchmark 
To benchmark our implementation of bit packing, we measure the elapsed time taken by the execution of each functions of the `BitPacking` class: 
- `main.BitPacking.compress`: for the compression of the data,
- `main.BitPacking.decompress`: for the decompression of the data,
- `main.BitPacking.transmit`: to mimic the transmission of data through serialisation and buffers (write and read) of either the compressed data and the uncompressed data.

This way we can compare for each input files (12 differents) and compute the error margin of elapsed time if we repeat this process a certain number of time.

As a reminder, the error margin at 95% is roughly computed as:
$$
\text{EM} = \mu\pm1.96\frac{\sigma}{\sqrt{n}}
$$

where $\mu$ is the average of our data, $\sigma$ the standard deviation and $n$ the size of our data.

Optionally, we may also perform statistical tests on the results to assess the gain in speed.