package com.fuse.camera;

import java.io.File;
import java.io.FileInputStream;
import java.util.Arrays;
import java.util.Locale;

final class ImageFrameCounter {

	private static final long MAX_FILE_SIZE = 32L * 1024 * 1024;

	private ImageFrameCounter() {
	}

	static int getFrameCount(String path) {
		try {
			String mime = ImageUtils.getMimeType(path);
			if (mime == null)
				return 1;

			mime = mime.toLowerCase(Locale.ROOT);
			if (mime.contains("gif"))
				return countGifFrames(readFileBytes(path));
			if (mime.contains("webp"))
				return countWebpFrames(readFileBytes(path));

			return 1;
		} catch (Exception e) {
			return 1;
		}
	}

	static byte[] readFileBytes(String path) throws Exception {
		File file = new File(path);
		if (file.length() <= 0 || file.length() > MAX_FILE_SIZE)
			return null;

		byte[] data = new byte[(int)file.length()];
		FileInputStream in = new FileInputStream(file);

		try {
			int offset = 0;
			while (offset < data.length) {
				int read = in.read(data, offset, data.length - offset);
				if (read <= 0)
					break;
				offset += read;
			}

			if (offset < data.length)
				return Arrays.copyOf(data, offset);

			return data;
		} finally {
			in.close();
		}
	}

	static int countGifFrames(byte[] data) {
		if (data == null || data.length < 13)
			return 1;

		int screenPacked = data[10] & 0xFF;
		int position = 13;

		if ((screenPacked & 0x80) != 0)
			position += 3 * (1 << ((screenPacked & 0x07) + 1));

		int frames = 0;

		while (position < data.length) {
			int block = data[position] & 0xFF;

			if (block == 0x3B)
				break;

			if (block == 0x21) {
				if (position + 2 > data.length)
					break;
				position += 2;
				position = skipSubBlocks(data, position);
			} else if (block == 0x2C) {
				frames++;

				if (position + 10 > data.length)
					break;

				int packed = data[position + 9] & 0xFF;
				position += 10;

				if ((packed & 0x80) != 0)
					position += 3 * (1 << ((packed & 0x07) + 1));

				if (position < data.length)
					position += 1; // LZW minimum code size

				position = skipSubBlocks(data, position);
			} else {
				break;
			}
		}

		return Math.max(1, frames);
	}

	static int skipSubBlocks(byte[] data, int position) {
		while (position < data.length) {
			int size = data[position] & 0xFF;
			position++;

			if (size == 0)
				break;

			position += size;
		}

		return position;
	}

	static int countWebpFrames(byte[] data) {
		if (data == null || data.length < 12)
			return 1;

		if (!(data[0] == 'R' && data[1] == 'I' && data[2] == 'F' && data[3] == 'F' &&
				data[8] == 'W' && data[9] == 'E' && data[10] == 'B' && data[11] == 'P'))
			return 1;

		int position = 12;
		int frames = 0;

		while (position + 8 <= data.length) {
			boolean isAnimationFrame = data[position] == 'A' && data[position + 1] == 'N' &&
				data[position + 2] == 'M' && data[position + 3] == 'F';

			long size = (data[position + 4] & 0xFFL) |
				((data[position + 5] & 0xFFL) << 8) |
				((data[position + 6] & 0xFFL) << 16) |
				((data[position + 7] & 0xFFL) << 24);

			if (isAnimationFrame)
				frames++;

			long next = position + 8 + size + (size & 1);
			if (next <= position || next > data.length)
				break;

			position = (int)next;
		}

		return Math.max(1, frames);
	}
}
