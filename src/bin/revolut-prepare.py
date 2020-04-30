import csv
import sys
from datetime import datetime

fields = ['Date completed', 'Description', 'Amount', 'Balance']

data = []

with open(sys.argv[1], encoding="utf-8-sig") as csvfile:
    reader = csv.DictReader(csvfile)
    for row in reader:
        data.append(row)

data.reverse()

writer = csv.writer(sys.stdout)
writer.writerow(fields)

for i, row in enumerate(data):
    row['Date completed'] = datetime.strptime(row['Date completed'], '%Y-%m-%d').strftime('%d/%m/%Y')
    if row['Fee']:
        row['Amount'] = round(float(row['Amount']) + float(row['Fee']), 2)
    writer.writerow([row[field] for field in fields])
