import boto3
import datetime

def lambda_handler(event, context):
    rds = boto3.client('rds')
    db_id = "wordpress-db"  # must match your db identifier

    timestamp = datetime.datetime.utcnow().strftime("%Y-%m-%d-%H-%M-%S")
    snapshot_name = f"{db_id}-snapshot-{timestamp}"

    rds.create_db_snapshot(
        DBInstanceIdentifier=db_id,
        DBSnapshotIdentifier=snapshot_name
    )

    return {"status": "snapshot-created", "snapshot": snapshot_name}
