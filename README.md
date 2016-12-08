This series of tutorial aims at its corresponding major version of Timeless. For example, a version number of 1.x.x.x means it should be compatible with Timeless version >= 1 and < 2.

As a project goal, this tutorial series will also aid the development and refactor of Timeless. Major breakage is unlikely if you don't use underlying Signals directly. However, if you do, good luck. And it is important that, if you have seen my timeless-0.9.x.x tutorials, they would probably still work with modifications. However, that version is way too primitive and messy to write, and doesn't really give any advantage of FRP, and gave me much more headache than writing using "normal" methods.

This series should hopefully guide you to be familiar with "my" way of FR. Of course, I do not have real serious UI experiences, so I am also learning. Again, expect radical changes, but the code should still work.

Feel free to skip this section if you don't want to read stories.

Now, why would I write Timeless?

Because I intuitively think FRP is the way to go. I have read Functional Reactive Programming, and I tried to learn Netwire because of the nice Arrow syntax.

And of course, Timeless is forked originally from Netwire 5 because it is unmaintained and incomplete. And Timeless is just a random name I gave it. As of version 1, Timeless is really, timeless, because I removed the Session(with time information) that feeds into every Signal, as inherited from Netwire. The reason is, I think this makes reasoning with purity much harder, and I'd rather explicitly put down an IO signal just to read the time. That should compose much better.

Timeless 1 imitates the primitives like Sodium as described in the book Functional Reactive Programming. Of course, since Timeless works on Arrows instead of end points, exact details are different, and will be shown in the tutorials.
