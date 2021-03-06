module secured.hash;

import std.stdio;

version(OpenSSL)
{
import deimos.openssl.evp;
}
version(Botan)
{
import botan.hash.sha2_64;
}

import secured.util;

@trusted public ubyte[] hash(ubyte[] data)
{
	version(OpenSSL)
	{
		//Create the OpenSSL context
		EVP_MD_CTX *mdctx;
		if ((mdctx = EVP_MD_CTX_create()) == null)
			throw new CryptographicException("Unable to create OpenSSL context.");
		scope(exit)
			if(mdctx !is null)
				EVP_MD_CTX_destroy(mdctx);

		//Initialize the SHA-384 algorithm
		if (EVP_DigestInit_ex(mdctx, EVP_sha384(), null) < 0)
			throw new CryptographicException("Unable to create SHA-384 hash context.");

		//Run the provided data through the digest algorithm
		if (EVP_DigestUpdate(mdctx, data.ptr, data.length) < 0)
			throw new CryptographicException("Error while updating digest.");

		//Copy the OpenSSL digest to our D buffer.
		uint digestlen;
		ubyte[] digest = new ubyte[48];
		if (EVP_DigestFinal_ex(mdctx, digest.ptr, &digestlen) < 0)
			throw new CryptographicException("Error while retrieving the digest.");

		return digest;
	}

	version(Botan)
	{
		auto sha = new SHA384();
		scope(exit)
			sha.clear();

		sha.update(data.ptr, data.length);

		auto digestvec = sha.finished();
		ubyte[] digest = new ubyte[digestvec.length];
		for(int i = 0; i<digestvec.length; i++)
			digest[i] = digestvec[i];
		return digest;
	}
}

unittest {
	import std.digest.digest;

	writeln("Testing Byte Array Hash:");

	ubyte[] vec1 = hash(cast(ubyte[])"");
	ubyte[] vec2 = hash(cast(ubyte[])"abc");
	ubyte[] vec3 = hash(cast(ubyte[])"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq");
	ubyte[] vec4 = hash(cast(ubyte[])"The quick brown fox jumps over the lazy dog.");

	writeln(toHexString!(LetterCase.lower)(vec1));
	writeln(toHexString!(LetterCase.lower)(vec2));
	writeln(toHexString!(LetterCase.lower)(vec3));
	writeln(toHexString!(LetterCase.lower)(vec4));

	assert(toHexString!(LetterCase.lower)(vec1) == "38b060a751ac96384cd9327eb1b1e36a21fdb71114be07434c0cc7bf63f6e1da274edebfe76f65fbd51ad2f14898b95b");
	assert(toHexString!(LetterCase.lower)(vec2) == "cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7");
	assert(toHexString!(LetterCase.lower)(vec3) == "3391fdddfc8dc7393707a65b1b4709397cf8b1d162af05abfe8f450de5f36bc6b0455a8520bc4e6f5fe95b1fe3c8452b");
	assert(toHexString!(LetterCase.lower)(vec4) == "ed892481d8272ca6df370bf706e4d7bc1b5739fa2177aae6c50e946678718fc67a7af2819a021c2fc34e91bdb63409d7");
}

@trusted public ubyte[] hash(string path)
{
	//Open the file for reading
	auto fsfile = File(path, "rb");
	scope(exit)
		if(fsfile.isOpen())
			fsfile.close();

	version(OpenSSL)
	{
		//Create the OpenSSL context
		EVP_MD_CTX *mdctx;
		if ((mdctx = EVP_MD_CTX_create()) == null)
			throw new CryptographicException("Unable to create OpenSSL context.");
		scope(exit)
			if(mdctx !is null)
				EVP_MD_CTX_destroy(mdctx);

		//Initialize the SHA-384 algorithm
		if (EVP_DigestInit_ex(mdctx, EVP_sha384(), null) < 0)
			throw new CryptographicException("Unable to create SHA-384 hash context.");

		//Read the file in chunks and update the Digest
		foreach(ubyte[] data; fsfile.byChunk(FILE_BUFFER_SIZE))
		{
			if (EVP_DigestUpdate(mdctx, data.ptr, data.length) < 0)
				throw new CryptographicException("Error while updating digest.");
		}

		//Copy the OpenSSL digest to our D buffer.
		uint digestlen;
		ubyte[] digest = new ubyte[48];
		if (EVP_DigestFinal_ex(mdctx, digest.ptr, &digestlen) < 0)
			throw new CryptographicException("Error while retrieving the digest.");

		return digest;
	}

	version(Botan)
	{
		auto sha = new SHA384();
		scope(exit)
			sha.clear();

		//Read the file in chunks and update the Digest
		foreach(ubyte[] data; fsfile.byChunk(FILE_BUFFER_SIZE))
		{
			sha.update(data.ptr, data.length);
		}

		auto digestvec = sha.finished();
		ubyte[] digest = new ubyte[digestvec.length];
		for(int i = 0; i<digestvec.length; i++)
			digest[i] = digestvec[i];
		return digest;
	}
}

unittest {
	import std.digest.digest;

	writeln("Testing File Hash:");

	auto f = File("hashtest.txt", "wb");
	f.rawWrite("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq");
	f.close();

	ubyte[] vec = hash("hashtest.txt");
	writeln(toHexString!(LetterCase.lower)(vec));
	assert(toHexString!(LetterCase.lower)(vec) == "3391fdddfc8dc7393707a65b1b4709397cf8b1d162af05abfe8f450de5f36bc6b0455a8520bc4e6f5fe95b1fe3c8452b");

	remove("hashtest.txt");
}
