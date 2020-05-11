# aws-ec2-jvm-monitoring

## Requirements

* `jq` installed
* `aws-cli` installed

## jstat

The script uses jstat to collect information about the jvm heap.

Short Name | Name
----- | ----
S0C | CURRENT SURVIVOR SPACE 0 CAPACITY (KB).
S1C | CURRENT SURVIVOR SPACE 1 CAPACITY (KB).
S0U | SURVIVOR SPACE 0 UTILIZATION (KB).
S1U | SURVIVOR SPACE 1 UTILIZATION (KB).
EC | CURRENT EDEN SPACE CAPACITY (KB).
EU | EDEN SPACE UTILIZATION (KB).
OC | CURRENT OLD SPACE CAPACITY (KB).
OU | OLD SPACE UTILIZATION (KB).
PC | CURRENT PERMANENT SPACE CAPACITY (KB).
PU | PERMANENT SPACE UTILIZATION (KB).
YGC | NUMBER OF YOUNG GENERATION GC EVENTS.
YGCT | YOUNG GENERATION GARBAGE COLLECTION TIME.
FGC | NUMBER OF FULL GC EVENTS.
FGCT | FULL GARBAGE COLLECTION TIME.
GCT | TOTAL GARBAGE COLLECTION TIME.

## Usage

```sh
jvm-mon.sh --stats stat0[, statN]
```

For the statistics, you can add any of the above mentioned short names to publish it. E.g.:

```sh
# publish capacity and utilization for both survivor spaces
jvm-mon.sh --stats s0c,s1c,s0u,s1u
```

In addition, you can use the following for aggregated statistics:

Parameter | Description
--------- | -----------
capacity | Sum of all capacities of survivor, eden and old psace (S0C+S1C+EC+OC)
util | Sum of all utilizations of survivor, eden and old space (S0U+S1U+EU+OU)


### Using Elastic Beanstalk

```yml
packages:
  yum:
    jq: []
sources: 
  /opt/cloudwatch: https://github.com/0ptional/aws-ec2-jvm-monitoring/releases/download/1.0/CloudWatchJVMMonitoringScripts-1.0.zip
  
container_commands:
  01-setupcron:
    command: |
      echo '*/1 * * * * root /opt/cloudwatch/aws-scripts-jvm-mon/jvm-mon.sh --stats s0u,s1u,eu,ou >> /var/log/cw_jvm_mon' > /etc/cron.d/cw_jvm_mon
  02-changeperm:
    command: chmod u+x /opt/cloudwatch/aws-scripts-jvm-mon/jvm-mon.sh
```
