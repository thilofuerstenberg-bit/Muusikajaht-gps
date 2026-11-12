# Muusikajaht GPS — deployment

## 1. GitHub Pages
The files are in this repository. Go to **Settings > Pages > Build and deployment > Deploy from a branch > main / (root) > Save**. Once published, open https://thilofuerstenberg-bit.github.io/Muusikajaht-gps/ (GitHub Pages paths are case-sensitive).

## 2. Create Supabase backend
Create a project at https://supabase.com/dashboard. In SQL Editor run the full `schema.sql`. In Authentication > Providers enable **Anonymous Sign-ins** (for students), and **Email** (for teachers). In Authentication > URL Configuration set the Site URL to the exact GitHub Pages URL and add that URL to Redirect URLs. In Project Settings > API copy the Project URL and publishable/anon key into `config.js`. NEVER put the service_role or secret key in client files. Commit updated `config.js` to GitHub.

## 3. Authorize the teacher
Open the deployed app, select Teacher, enter your email and request an email link. Click the link in your email. In Supabase SQL Editor run:
`insert into public.teachers(user_id) select id from auth.users where email='YOUR_EMAIL' on conflict do nothing;`
Replace YOUR_EMAIL with the exact email used. Reload the site and select Teacher. Click a station in the dropdown, then click the map to place it. Repeat 12 times. Select station radius 30–50m (GPS is imprecise).

## 4. Students
Share the GitHub Pages link. Students select Student, enter a team name, allow GPS, walk to each marker, and submit answers or evidence. The teacher dashboard refreshes every 15 seconds. Media is private in the `music-evidence` Supabase Storage bucket; the teacher gets a temporary signed link to view a file. Media is limited to 20 MB per upload. Videos must be short and compressed; use photos when possible.

## 5. Privacy, testing and safety
Use team aliases, not full student names. Do not film people without appropriate school permissions. Avoid capturing faces or voices where not needed. Supabase stores the submissions until you delete them; establish a deletion date after the lesson. GPS coordinates are used on-device for proximity and are **not stored** in submissions. Student browser GPS checks are not tamper-proof; treat as a game, not a secure attendance system. Test with one teacher and one student device before the lesson. Students need mobile internet, location permission and HTTPS. The teacher must define a safe boundary and supervise students.

## Important limitation
The Supabase project must be configured before the app can go live. This is a starter implementation and has not yet been end-to-end tested. Quiz scoring happens in Supabase; teacher creative-task points are assigned manually. No automatic photo/video content analysis is performed.