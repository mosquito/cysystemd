import asyncio

from cysystemd.async_reader import AsyncJournalReader
from cysystemd.reader import JournalOpenMode


async def main():
    reader = AsyncJournalReader()
    await reader.open(JournalOpenMode.SYSTEM)
    await reader.seek_tail()

    while await reader.wait():
        async for record in reader:
            print(record.data["MESSAGE"])


if __name__ == "__main__":
    asyncio.run(main())
