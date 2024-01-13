#!/usr/bin/env python
import os
import json
import http.client
from urllib.request import urlretrieve

class CircleCI:
    def __init__(self, token):
        self.token = token

    def get_workflow_job(self, workflow_id):
        url = f"/api/v2/workflow/{workflow_id}/job"
        return self.make_request("GET", url)

    # job artifacts
    def get_job_artifacts(self, project_slug, job_id):
        url = f"/api/v2/project/{project_slug}/{job_id}/artifacts"
        return self.make_request("GET", url)

    def make_request(self, method, url):
        conn = http.client.HTTPSConnection("circleci.com")
        headers = {'authorization': f"Bearer {self.token}"}
        conn.request(method, url, headers=headers)
        res = conn.getresponse()
        data = res.read()
        return data

def main():
    workflow_id = os.environ.get('CIRCLE_WORKFLOW_ID')
    token = os.environ.get('CIRCLE_TOKEN_ID')

    # Check if environment variables are set
    if not workflow_id:
        raise ValueError("CIRCLE_WORKFLOW_ID environment variable is missing")
    if not token:
        raise ValueError("CIRCLE_TOKEN_ID environment variable is missing")

    dir = "artifacts"
    # create an artifacts directory
    if not os.path.exists(dir):
        os.makedirs(dir)

    circle_ci = CircleCI(token)
    data = circle_ci.get_workflow_job(workflow_id)

    json_data = json.loads(data.decode("utf-8"))

    # iterate over all jobs and fetch artifacts
    for job in json_data['items']:
        job_id = job['job_number']
        project_slug = job['project_slug']
        job_name = job['name']
        print(f"Fetching artifacts for job {job_name} with id {job_id}")
        artifacts = circle_ci.get_job_artifacts(project_slug, job_id)
        json_data = json.loads(artifacts.decode("utf-8"))

        for item in json_data['items']:
            local_path = f"{dir}/{job_id}_{item['path']}"
            url = item['url']
            print(f"Downloading artifact from {url} to {local_path}")
            urlretrieve(url, local_path)

    # zip the artifacts directory
    os.system(f"zip -r artifacts.zip {dir}")

if __name__ == "__main__":
    main()

  
