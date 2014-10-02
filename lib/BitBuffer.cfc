<cfscript>
// NOTE: CFScript used for GitHub color coding. Can be removed.
component
	output = false
	hint = "I provide a way to build and transform a collection of bits."
	{

	/**
	* I initialize the bit 
	* 
	* @input I am a binary value (byte array) used to initialize the buffer.
	* @output false
	*/
	public any function init( required binary input ) {

		// The buffer will start empty (this count only gets updated when data is 
		// actually written to the underlying BitSet).
		bitCount = 0;

		// The underlying BitSet will be pre-allocated with enough bits to accomodate
		// the initialization value. It will also grow as needed, but this will be
		// more performant in the meantime.
		bits = createObject( "java", "java.util.BitSet" ).init(
			javaCast( "int", ( arrayLen( input ) * 8 ) )
		);

		// Write the input to the underyling BitSet.
		appendBytes( input );

	}


	// ---
	// STATIC METHODS.
	// ---


	/**
	* I return a new BitBuffer instance using the bytes of the given string.
	* 
	* @input I am a string value used to initialize a new buffer instance.
	* @output false
	*/
	public any function fromString( required string input ) {

		return( new BitBuffer( charsetDecode( input, "utf-8" ) ) );

	}


	// ---
	// PUBLIC METHODS.
	// ---


	/**
	* I append the given byte (8 bits) to the buffer. The bits are added in the order
	* of most-significant bit to the least-significant bit.
	* 
	* @byte I am a numeric value, but only the least-significant 8-bits matter.
	* @output false
	* @hint I return the BitBuffer reference.
	*/
	public any function appendByte( required numeric byte ) {

		// Add bits, left to right, to the end of the BitSet.
		for ( var i = 7 ; i >= 0 ; i-- ) {

			bits.set(
				javaCast( "int", bitCount++ ),
				javaCast( "boolean", bitMaskRead( byte, i, 1 ) )
			);

		}

		return( this );

	}


	/**
	* I append the given bytes to the buffer. 
	* 
	* @output false
	* @hint I return the BitBuffer reference.
	*/
	public any function appendBytes( required binary bytes ) {

		for ( var byte in bytes ) {

			appendByte( byte );

		}

		return( this );

	}


	/**
	* I get the bit value at the given index (1-based).
	* 
	* @index I am the 1-based index of the bit to get.
	* @output false
	*/
	public boolean function getBit( required numeric index ) {

		// Subtracting 1 to make input more ColdFusion compatible, while keeping 
		// the Java layer zero-based.
		return( bits.get( javaCast( "int", ( index - 1 ) ) ) );

	}


	/**
	* I return the number of bits currently stored in the buffer.
	* 
	* @output false
	*/
	public numeric function getSize() {

		return( bitCount );

	}


	/**
	* I set the bit value at the given index (1-based).
	* 
	* @index I am the 1-based index of the bit to set.
	* @value I am the boolean value that indicates if the bit should be turend on (true).
	* @output false
	* @hint I return the BitBuffer reference. 
	*/
	public any function setBit( 
		required numeric index,
		required boolean value
		) {

		// Subtracting 1 to make input more ColdFusion compatible, while keeping 
		// the Java layer zero-based.
		bits.set( 
			javaCast( "int", ( index - 1 ) ),
			javaCast( "boolean", value )
		);

		// If the index is beyond the bounds of the current length, then we have to 
		// update the length to encompass the newly assigned value.
		bitCount = max( bitCount, index );

		return( this );
	}


	/**
	* I shift the entire buffer left, appending zeros to the end (right) of the buffer.
	* 
	* @size I am a positive integer.
	* @output false
	* @hint I return the BitBuffer reference. 
	*/
	public any function shiftLeft( numeric size = 1 ) {

		if ( size < 1 ) {

			throw( 
				type = "InvalidArgument",
				message = "Size must be a positive integer."
			);

		}

		// Shifting left is easy - we don't actually have to move any bits around; we 
		// simply have to define the length of the bits as being longer.
		bitCount += size;

		return( this );

	}


	/**
	* I shift the entire buffer right, truncating bits off the end (right). Note that 
	* this does NOT append any bits to the left of the buffer.
	* 
	* @size I am a positive integer.
	* @output false
	* @hint I return the BitBuffer reference.
	*/
	public any function shiftRight( numeric size = 1 ) {

		if ( size < 1 ) {

			throw( 
				type = "InvalidArgument",
				message = "Size must be a positive integer."
			);

		}

		// If there are no bits, then just return the current reference.
		if ( ! bitCount ) {

			return( this );

		}

		// If we're trying to truncate more than the length of the current buffer, just
		// emty the current buffer.
		if ( size > bitCount ) {

			size = bitCount;

		}

		bitCount -= size;

		bits.set(
			javaCast( "int", bitCount ),
			javaCast( "int", ( bitCount + size ) ),
			javaCast( "boolean", false )
		);

		return( this );

	}


	/**
	* I transform the bits in the buffer, a chunk at a time. Each input chunk of 
	* [inputSize] bits is replaced with a resultant chunk of [outputSize] bits. The
	* callback will accept the input chunk and may return the output chunk. The chunks
	* are all numeric, so (for the moment), each chunk must fit into a 32-bit integer.
	* 
	* If no transformed value is returned, the given chunk is excluded from the 
	* resultant BitBuffer state.
	* 
	* If the inputSize does not evenly divide into the current set of bits, then zeros
	* will be added to the last callback chunk to ensure that all chunks are the same
	* length of bits.
	* 
	* @inputSize I am the number of bits to put into the input.
	* @outputSize I am the number of bits to extract from the transformed result chunk.
	* @callback I am a function that takes the input chunk and returns the output chunk.
	* @output false
	* @hint I return the BitBuffer reference.
	*/
	public any function transformBits(
		required numeric inputSize,
		required numeric outputSize,
		required any callback
		) {

		// When transforming the bits, we may create a new set of bits that is either 
		// longer than, or shorter than, or equal to the original set of bits. As such,
		// we're going to make our lives simple by just writing the bits to an entirely
		// new BitSet.
		var transformedBits = createObject( "java", "java.util.BitSet" ).init(
			javaCast( "int", ceiling( bitCount / inputSize * outputSize ) )
		);

		var transformedBitCount = 0;

		// Loop over each chunk of the input.
		for ( var chunkOffset = 0 ; chunkOffset < bitCount ; chunkOffset += inputSize ) {

			var input = 0;

			// Build up the input value, one bit at a time. 
			for ( var i = 0 ; i < inputSize ; i++ ) {

				if ( bits.get( javaCast( "int", ( chunkOffset + i ) ) ) ) {

					input = bitMaskSet( input, 1, ( inputSize - i - 1 ), 1 );

				}

			}

			var output = callback( input );

			// If no transformed value was returned, skip on to the next chunk.
			if ( ! structKeyExists( local, "output" ) ) {

				continue;

			}

			// Apply the transformed value, left-to-right, to the end of the new BitSet.
			for ( var i = ( outputSize - 1 ) ; i >= 0 ; i-- ) {

				transformedBits.set(
					javaCast( "int", transformedBitCount++ ),
					javaCast( "boolean", bitMaskRead( output, i, 1 ) )
				);

			}

		}

		// Store the new BitSet as the internal representation of this BitBuffer.
		bits = transformedBits;
		bitCount = transformedBitCount;

		return( this );

	}


	/**
	* I convert the BitBuffer into a binary value. If the underlying set of bits does
	* not evently divide by 8 (the number of bits in a byte), the remainder bits will
	* be excluded from the binary value.
	* 
	* @output false
	*/
	public binary function toByteArray() {

		var byteBuffer = createObject( "java", "java.nio.ByteBuffer" ).allocate(
			javaCast( "int", fix( bitCount / 8 ) )
		);

		return( writeBitsToByteBuffer( byteBuffer ).array() );

	}


	/**
	* I convert the BitBuffer into a binary value. If the underlying set of bits does
	* not evently divide by 8 (the number of bits in a byte), the remainder bits will
	* be used as the most-significant bits of an additional byte added to the end of
	* the resultant binary value.
	* 
	* @output false
	*/
	public binary function toPaddedByteArray() {

		var byteBuffer = createObject( "java", "java.nio.ByteBuffer" ).allocate(
			javaCast( "int", ceiling( bitCount / 8 ) )
		);

		return( writeBitsToByteBuffer( byteBuffer ).array() );

	}


	// ---
	// PRIVATE METHODS.
	// ---


	/**
	* I write the current bits to the given ByteBuffer. Any overflow of bits will be
	* implicitly handled by the size of the ByteBuffer.
	* 
	* @output false
	*/
	private any function writeBitsToByteBuffer( required any byteBuffer ) {

		// When converting bits to bytes, we have to take into account the fact that 
		// Java uses signed bytes. Which means that if the 8th bit, in our pending byte
		// (which is actually an Int) is turned-on, we have to convert that to a negative
		// 32-bit number in order to get the last 8 bits to make a negative number.
		var negativeMask = inputBaseN( ( "11111111" & "11111111" & "11111111" & "00000000" ), 2 );

		// Keep writing bytes to the ByteBuffer while there is space left.
		for ( var byteOffset = 0 ; byteBuffer.hasRemaining() ; byteOffset += 8 ) {

			var byte = 0;

			// Build up the current byte, left to right.
			for ( var i = 0 ; i < 8 ; i++ ) {

				if ( bits.get( javaCast( "int", ( byteOffset + i ) ) ) ) {

					byte = bitMaskSet( byte, 1, ( 8 - i - 1 ), 1 );

				}

			}

			// If the 8th-bit is enabled, we have to convert to a negative 32-bit 
			// number so that the last 8 bits will represent a negative number.
			if ( bitMaskRead( byte, 7, 1 ) ) {

				byte = bitOr( negativeMask, byte );

			}

			byteBuffer.put( javaCast( "byte", byte ) );
			
		}

		return( byteBuffer );

	}

}
</cfscript>