# Offline design

Everything in Offline Lab assumes that internet is either unavailable or unreliable.

## No network dependencies

The OS never waits for a network connection during boot. No NTP, no connectivity checks, no DNS resolution required to reach a running system.

Time synchronization will use alternatives in a later phase: Meshtastic, manual set, or GPS.

## The cutoff model

The platform works around the concept of a "cutoff": a point after which internet is no longer available. Before cutoff, data is synced: package mirrors, content databases, maps, media. After cutoff, the system runs on what it has. See [Packages](packages.md) for the provisioning model.

This is not sudden. Users prepare by running sync tools while internet is available, building up the content and images they need.

## Security after cutoff

After cutoff, no new security patches are available.

The root filesystem is read-only, limiting the attack surface and preventing persistent OS compromise. The network tracks which devices are connected. Only ports that services need are open. There is no inbound internet connection to exploit.

Security degrades over time after cutoff. This is an accepted trade-off. The platform prioritizes function over indefinite hardening in a disconnected environment.

## Data integrity

SD cards degrade over time, especially under write load. The read-only root eliminates writes to the OS partition. Writable data is concentrated on `/data`. A/B root partitions allow recovering from corruption by reflashing one slot.

Data sync between nodes for redundancy is a future goal.

## Single-node architecture

Each device runs its services independently. No distributed databases, no replication, no load balancers. If the network goes down, each node's local services keep working.

The platform targets small communities, roughly 20 to 30 concurrent users per node. This is not a data center. Everything for a service runs on a single node.

All state for a service lives on the local `/data` partition. SQLite is the only database engine. Services are tuned for low concurrency, not throughput. Multiple services can run on the same device. See the [service model](components.md) for how services are packaged and managed.

## Bootstrap

An empty node with no data cannot be used after cutoff. Initial setup requires either internet access or another already-prepared node. Users prepare by running sync tools while internet is available, building up the content and images they need before going offline.
