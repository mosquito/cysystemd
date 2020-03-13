import asyncio
import json

from cysystemd.reader import JournalOpenMode
from cysystemd.async_reader import AsyncJournalReader


async def main():
    reader = AsyncJournalReader()
    await reader.open(JournalOpenMode.SYSTEM)
    await reader.seek_tail()

    while await reader.wait():
        async for record in reader:
            print(
                json.dumps(
                    record.data, indent=1, sort_keys=True
                )
            )


if __name__ == '__main__':
    asyncio.run(main())
