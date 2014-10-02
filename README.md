
# BitBuffer.cfc - Bit Transformations In ColdFusion

by [Ben Nadel][bennadel] (on [Google+][googleplus])

When I was playing about with Base32 encoding in ColdFusion, I noticed that a great
deal of the complexity revolved around transforming one set of Bytes into another set
of Bytes. It occurred to me that this complexity could be greatly reduced if the 
transformation was encapsulated behind a simple transform function.

To accomplish this, I created BitBuffer.cfc, which presents a bit-based interface over
an underlying set of binary data. The BitBuffer.cfc exposes a transform method which 
presents inputs of a given bit size and accepts bit outputs of a [potentially different]
size:

* transformBits( inputSize, outputSize, callback )

The Callback is a ColdFusion function which accepts a numeric input and returns a numeric
result. When the result is rolled into the underlying buffer, only the least-significant
bits, as dictated by the `outputSize`, are added to the buffer.

If the callback does not return any value, the current input it excluded entirely from 
the resultant buffer.

Once the transformation is complete, the BitBuffer can be transformed back into a binary
value (byte array) by using one of the following methods:

* toByteArray()
* toPaddedByteArray()

Both of these methods return a binary value. The difference is in the potential size of 
binary value. If the underlying bit-set does not evenly divide into 8 (8 bits in a byte),
the `toByteArray()` will simply exclude the bits that don't fit. The `toPaddedByteArray()`
method, on the other hand, will pad the underlying bit-set with zeros (least-significant
bits) in order to complete the last byte.


[bennadel]: http://www.bennadel.com
[googleplus]: https://plus.google.com/108976367067760160494?rel=author