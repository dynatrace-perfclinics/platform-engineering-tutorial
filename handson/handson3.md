### Hands-On 3: Setting up an SRG (Site Reliability Guardian)

Now that we have our first version of our applications deployed we want to validate that the next time a new version gets deployed our applications are still healthy and running!

For this we will be doing three steps:
1. Create a Site Reliability Guardian (SRG) to validate our key objectives of our service
2. Trigger that SRG from a Workflow for a `deployment.validated` lifecycle event
3. Send a notification message to our Backstage Notification Plugin

Here is a quick overview of what we want to achieve:

![](https://raw.githubusercontent.com/dynatrace-perfclinics/platform-engineering-tutorial/main/images/handson3_srgoverview_animated.gif)

--- 

#### 3.1 Create a Site Reliability Guardian (SRG) for our service

To learn more about the Site Reliability Guardian (SRG) also watch [Dynatrace App Spotlight: SRG](https://www.youtube.com/watch?v=s3KG4kn-ymY)

As indicated in the video, creating an SRG can start with picking an existing template or creating one from scratch. In our Hands-On we will create an SRG from scratch. Here are the steps:
1. Open the SRG App and click on `+ Guardian`
2. Select `create without template` and give it a good name
3. Add one objective 
4. Specify `Availability` and choose the `Availability SLO` for your service
5. `Create and Validate` 
6. Validate the result

Here are those steps visually explained

![](https://raw.githubusercontent.com/dynatrace-perfclinics/platform-engineering-tutorial/main/images/handson3_31_createsrg_1.png)

#### 3.2 Create a Workflow for the Guardian

As we have validated that the guardian works based on our current set of objectives its time to automate the execution. For this we can create a workflow straight from the Guardian App. What we need to adjust is 
1. The trigger of the workflow should be from a successful `deployment.validated` for our respective application
2. Using the last 30 minutes as evaluation timeframe (NOT BEST PRACTICE - BUT GOOD FOR THE START)

Here are those steps visually explained

![](https://raw.githubusercontent.com/dynatrace-perfclinics/platform-engineering-tutorial/main/images/handson3_32_automate_srg_1.png)

#### 3.3 Execute the Workflow and validate its working

We can manually trigger a workflow at any time. When clicking `Run` we will be prompted with a sample event that will be used to execute the workflow. As we have earlier queried the events that match our filter the event proposed will be one of our previous `deployment.validated` lifecycle events.

![](https://raw.githubusercontent.com/dynatrace-perfclinics/platform-engineering-tutorial/main/images/handson3_33_run_srg_workflow_1.png)

#### 3.4 Extend Workflow with a Notification

As a last step we can extend the Workflow to also send the result of the Guardian to our Notification system. In *the real world* this could be Slack, EMail, creating a JIRA Ticket. In our case our Backstage Notification plugin will do.

Lets therefore add a new HTTP Request task as shown below in the image. Here the additional information you need for setting up this task:
1. URL: `https://backstage.dtulabXXXXXXXXXXXX.dynatrace.training/api/notifications`
2. Payload
```
{
  "message": "SRG Result for {{ event()["app_name"] }}: {{ result("run_validation").validation_status }}! See result: {{ result("run_validation").validation_url }} ",
  "channel": "{{event()["owner"] }}",
  "origin": "Guardian Workflow"
}
```

![](https://raw.githubusercontent.com/dynatrace-perfclinics/platform-engineering-tutorial/main/images/handson3_34_add_notifications_1.png)