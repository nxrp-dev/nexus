using System;
using System.Collections.Generic;
using System.Configuration;
using System.Linq;
using System.Net.Mail;

namespace psMakeMail
{
    public class Program
    {
        private static string sendTo = "";
        private static string subject = "";
        private static string body = "";
        private static string attachment = "";

        private static List<string> missingRequiredArguments = new List<string>();
        private static List<string> unrecognizedArguments = new List<string>();

        public static void Main(string[] args)
        {
            if (!IsValidCommand(args))
            {
                if (missingRequiredArguments.Any())
                    missingRequiredArguments.ForEach(a => Console.WriteLine(a));

                if (unrecognizedArguments.Any())
                    unrecognizedArguments.ForEach(a => Console.WriteLine(a));

                ShowUsage();
            }
            else
                SendEmail();
        }

        private static void ShowUsage()
        {
            var p = typeof(Program).Assembly.GetName().Name;
            var usage = $@"
{p}: Sends email, for use with psMake.

Usage:
    -to       Required, recipient's email address (separate multiple addresses with commas).
    -subject  Required, email subject line.
    -body     Optional, email body.
    -attachment
              Optional, attachment file path.

Example:
{p} -to jmaner@indigotulsa.com -subject Test -body ""Testing email."" -attachment C:\test.txt
";

            Console.WriteLine(usage);

            Console.WriteLine("Press any key to continue...");
            Console.ReadKey();
        }

        private static bool IsValidCommand(string[] args)
        {
            for (var a = 0; a < args.Length; a++)
                switch (args[a].ToLower())
                {
                    case "-to":
                        sendTo = args[++a];
                        break;
                    case "-subject":
                        subject = args[++a];
                        break;
                    case "-body":
                        body = args[++a];
                        break;
                    case "-attachment":
                        attachment = args[++a];
                        break;
                    default:
                        unrecognizedArguments.Add($"Unrecognized argument: {args[a]}");
                        break;
                }

            if (string.IsNullOrEmpty(sendTo))
                missingRequiredArguments.Add("Must provide an email address to which to send email.");
            if (string.IsNullOrEmpty(subject))
                missingRequiredArguments.Add("Please provide a subject line for the email.");

            return !(missingRequiredArguments.Any() || unrecognizedArguments.Any());
        }

        private static void SendEmail()
        {
            var emailFrom = ConfigurationManager.AppSettings["emailFrom"];
            var smtpServer = ConfigurationManager.AppSettings["smtpServer"];
            var port = ConfigurationManager.AppSettings["emailPort"];
            var userID = ConfigurationManager.AppSettings["emailUserID"];
            var password = ConfigurationManager.AppSettings["emailPassword"];
            var enableSSL = ConfigurationManager.AppSettings["emailEnableSSL"];

            var mail = new MailMessage
            {
                From = new MailAddress(emailFrom),
                Subject = subject,
                Body = body,
            };
            mail.To.Add(sendTo);

            if (!string.IsNullOrEmpty(attachment))
                mail.Attachments.Add(new Attachment(attachment));

            var smtpClient = new SmtpClient(smtpServer)
            {
                Port = Convert.ToInt32(port),
                Credentials = new System.Net.NetworkCredential(userID, password),
                DeliveryMethod = SmtpDeliveryMethod.Network,
                EnableSsl = Convert.ToBoolean(enableSSL),
                //TargetName = "STARTTLS/smtp.office365.com",
            };

            smtpClient.Send(mail);
        }
    }
}
