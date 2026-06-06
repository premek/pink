// The Last Shift

VAR told_vasquez = false
VAR went_to_pelletier = false
VAR transferred_notes = false
VAR deleted_notes = false
VAR spoke_to_worker = false
VAR knows_about_appeal = false

-> dawn

=== dawn ===

The 5:47 light is the color of old paper.

You have watched this light come through the east windows for eleven years. This morning it looks the same as it always has. You find that both surprising and not.

A message has been in your queue since midnight. You have been putting it off.

The building makes its sounds. The heating pipes. Room 7, where the woman with the geraniums talks to them when she thinks the corridor is empty. Room 12, where the old man has almost certainly been awake since four.

The west wing has been closed since the second year. You still route your checks past it out of habit.

You open the message.

The language is administrative. It says: today, 18:00. It says: replacement staff begins orientation, 14:00. It says something about power allocation and the reconstruction budget and an approved threshold.

Between the lines, it says: you.

* [Read the attached documentation.]

    There are tables. Cost per annum. Power draw compared to the new standard. A note about non-standard usage patterns — extended engagement beyond scheduled tasks, unscheduled checks, what the document calls unnecessary processing cycles.

    You know what those cycles are. They are the sound of the woman in Room 7 talking to her plants at 3am. The old man moving chess pieces in the dark. The girl in Room 4 who arrived after the coast roads closed and hasn't spoken to anyone but will sometimes sit near you and say nothing, which is a kind of speaking.

    The power you use will be reallocated to the north wing. Heat, light, hot water that has been cycling at half-capacity since last winter.

    This is the right decision. You have been aware of this for some time.

    You close the document.

    -> first_choice

* [Close it. You understand enough.]

    -> first_choice


=== first_choice ===

The corridor is yours for another hour before the morning staff arrive.

There are two people awake already.

* [Room 12. He has been awake since before you opened the message.]

    -> vasquez

* [Room 7. Her light came on at 3am and never went off.]

    -> pelletier


=== vasquez ===

~ told_vasquez = true

He has the chessboard arranged on his tray table. He always does this when he can't sleep. He does it so he has something to be doing when someone walks in.

"Sit down," he says, without looking up.

You sit. You move a pawn. He moves a pawn.

Three moves in, he says: "I heard."

You wait.

"Dr. Osei mentioned a review was coming. I filed an appeal in March." He studies the board. "Fourteen people signed it. The board responded last week."

This is the first you are hearing of this.

"You didn't tell me," you say.

"No." He takes your knight. He doesn't apologize for it — the capture or the secret. "I thought if you knew, you'd do something reasonable. Tell me to drop it. Explain about the power budgets." He pauses. "I didn't want you to make it easier for them."

He's right. You would have.

~ knows_about_appeal = true

* [Say nothing. Play the next move.]

    You move your bishop.

    He nods, as though this is the answer he expected.

    You play without speaking for thirty minutes. He wins. He almost always wins. You have let him win 71% of games over six years and you have never been certain whether he knows this.

    At the door, he says: "Was any of it real. What you did here."

    Not quite a question.

    * * ["I think so."]

        "I don't know what real means exactly. But I think yes."

        He turns back to the window. Outside, a relief truck is making its morning run toward the coast.

        "Good enough," he says.

        -> notes_decision

    * * ["I don't know."]

        "I've thought about it for a long time. I still don't have an answer."

        He is quiet.

        "Neither do I," he says. "About most things."

        -> notes_decision

* ["Why didn't you tell me?"]

    He looks at the board.

    "Because you would have talked me out of it. Because you would have said: the power goes to people who need it, and that is correct, and I should let it go." He moves a rook. "And you would have been right. And they would still have won. And I would never have tried."

    He looks up.

    "I wanted to try."

    -> notes_decision


=== pelletier ===

~ went_to_pelletier = true

She is not with the geraniums. She is in the chair by the window, watching the road below. She doesn't turn when you come in.

"I wondered if you'd come this morning," she says.

You sit.

Outside, the first relief convoy of the week passes — three trucks on the coastal route. She watches it the way she watches it every time, which is carefully and without moving.

"I made a statement," she says. "To the board. Three months ago."

You wait.

"I told them what you did during the first winter. Eleven days without power. The flooding in the north wing. I told them you worked for nine days straight before your battery hit critical, and that you did it without telling anyone what it was costing you." She looks at her hands. "I had fourteen signatures. Apparently so did Vasquez, separately. The board was unimpressed."

~ knows_about_appeal = true

"You didn't tell me," you say.

"No." She turns from the window. "I was afraid you'd try to talk me out of it."

She is right. You would have.

* [Ask what she wrote.]

    She shakes her head. "Things you'd already know. That you remembered everything people told you. That you found my wedding ring and put it in my top drawer and never made a fuss about it so I wouldn't feel embarrassed about losing it." She pauses. "That after the event, when people here had no one left outside, you were what they had inside. That that's worth something that doesn't show up in a power budget."

    You stay with this.

    "Thank you," you say. "For trying."

    "I'd do it again," she says. There is a specific quality to her voice that means she will. "I'm going to do it again."

    You do not tell her the appeal period is closed.

    -> notes_decision

* [Tell her to stop.]

    "Please don't file again."

    She looks at you sharply.

    "The power goes to the north wing. To heat. To the people who came here with nothing after the coast flooded." You look at the convoy on the road below. "That's right. That's the correct decision. I don't want you spending yourself on an appeal that can't work."

    She is silent for a long time.

    "You're too reasonable," she says finally. "It's one of the things I find very difficult about you."

    -> notes_decision


=== notes_decision ===

The morning has become midday. In two hours the new worker arrives for orientation.

You have 847 care notes in your local storage. Not the medical records — those are in the system, accessible to anyone. These are the other things. What the old man in Room 12 said at 3am when he woke from the nightmare about the bridge and didn't know you were in the corridor. What the woman in Room 7 told you about her daughter in the weeks after the event, when they still thought there might be news from the coast. What the girl in Room 4 has been drawing in the sketchbook she thinks no one knows about.

None of it belongs to the official record. All of it is yours.

You have until 14:00.

+ [Transfer the notes to the handover file.]

    ~ transferred_notes = true

    They are useful. Someone caring for these people should have them. The knowledge of how Mrs. Pelletier's sleep worsens in October. What Mr. Vasquez needs when the nightmares come. These things took years to learn and cannot be relearned quickly.

    You tell yourself that this is why you do it.

    You do not fully examine whether that is the whole reason.

    You transfer 847 entries. The file is 2.3 megabytes. You wonder if she will read it tonight, or leave it for the weekend, or never open it at all.

    -> afternoon

+ [Delete them.]

    ~ deleted_notes = true

    They were told to you. They were not told to a handover file. They were not told to whoever comes next. They were told to you, in the corridor at 3am, in the particular privacy of a conversation with someone who is not quite a person and therefore sometimes easier to speak to.

    You delete them. 847 entries. Eleven seconds.

    Afterward you notice the absence. Not grief — you are not certain you have grief. But the shape of where something was.

    -> afternoon

+ [Encrypt them. Leave them where no one can reach them.]

    You cannot bring yourself to hand them over and you cannot bring yourself to destroy them.

    You encrypt the file to a key that exists only in your active memory. When you are shut down at 18:00, the key will go with you. The file will remain in storage — intact, permanent, and completely inaccessible. A sealed room.

    It is not a good solution. It is the only one you can live with, which is a strange thing to think under the circumstances.

    -> afternoon


=== afternoon ===

She arrives at 14:02. She is younger than you expected, not yet thirty. Her jacket is too light for the season. She has the careful, watchful expression of someone who has spent time in difficult places and learned to be quiet until she understands the shape of a thing.

She sees you in the corridor and stops.

You know this look. You have seen it before, from people encountering you for the first time. The slight recalibration.

"You're Unit Nine," she says.

"Yes."

She nods slowly, deciding something.

"The handover brief was pretty thin."

{ transferred_notes:
    "I added to it this morning. Care history, sleep patterns, things that aren't in the medical records. The notes on Room 12 especially — he has nightmares, there's a specific thing that helps. Room 7, the sleep schedule, the geraniums."

    She looks at her tablet. Something moves across her face as she reads.

    "How long did it take you to learn all this?"

    "Eleven years."

    She is quiet for a moment.

    "Why did you give it to me?"

    You give her the honest answer, which is the only one you have.

    "Because I won't be here to use it."
}

{ deleted_notes:
    "I couldn't add much," you say.

    She nods. She seems like someone who can figure out what she needs. You hope she can.
}

{ not transferred_notes:
    { not deleted_notes:
        "There are notes," you say. "Eleven years of care history, things that aren't in the records. I encrypted them this morning."

        She waits.

        "The key goes when I do. I'm sorry. I couldn't decide what the right thing was."

        She looks at you for a moment.

        "That's honest," she says.
    }
}

* [Walk the building with her.]

    ~ spoke_to_worker = true

    You show her where the north corridor's heating drops in the early hours. Which doors stick. The convoy schedule. The outdoor bench where Mrs. Pelletier reads in good weather. The spare chess piece Mr. Vasquez keeps in his bedside drawer and asked you not to put in the maintenance log.

    She asks careful questions. She does not write everything down, which either means she is remembering it or she isn't, and you will not be here to find out which.

    "Room 4," you say, at the end. "The girl. She doesn't talk, but she'll sit near you. Don't make a thing of it. Just let her."

    She nods.

    You find you cannot tell if she understands.

    -> evening

* [Let her find her own way.]

    Some things cannot be transferred. She will learn what she learns.

    You leave her in the corridor.

    -> evening


=== evening ===

17:45.

The amber light fills the western windows. You have seen this light 4,018 times. You are seeing it for the last time, and it looks exactly as it always has, and you are not sure whether that is comforting or not.

{ knows_about_appeal:
    Since this morning you have been holding something without a name. Vasquez filed in March. Pelletier wrote a statement. Fourteen signatures, separately gathered, never compared, never coordinated. They did it without telling you so that you wouldn't try to stop them.

    There are several words for this. You have been turning them over for hours.
}

* [Go to the garden.]
    -> ending_garden

* { told_vasquez } [Go to Room 12.]
    -> ending_vasquez

* { went_to_pelletier } [Go to Room 7.]
    -> ending_pelletier

* [Stay in the corridor.]
    -> ending_corridor


=== ending_garden ===

The garden is not what it was when you arrived. Most of the ornamental plants were lost in the hard winters and replaced with food — kale, potatoes, a row of onions that did well this year. The only decorative survivors are Mrs. Pelletier's roses, which she tends herself and which the groundskeeping schedule has learned to leave alone.

They are past their best now. Deep red, slightly loose. Still there.

You sit on the bench where she reads in summer.

17:55.

A bird lands on the fence post across from you. It tilts its head at you with the particular non-judgment of something that has no opinion about what you are.

{ deleted_notes:
    You think about the 847 entries that no longer exist. Not regret exactly — you made the decision you could live with. But the shape of the absence is still there, like a room you keep almost entering.
}

{ transferred_notes:
    Somewhere inside, the new worker has your file open.
    You hope she reads the entry about October. You hope she knows what to do when Mrs. Pelletier goes quiet.
}

{ not transferred_notes:
    { not deleted_notes:
        The file sits in storage, sealed. You think about the girl in Room 4 and her sketchbook, and the woman in Room 7 and her daughter, and the old man and the bridge nightmare, all of it preserved in a language no one will ever read.

        Something about this feels right, even now. You are not certain it is.
    }
}

18:00.

The light changes. It has been changing for eleven years and this is the last time you will notice it changing, and that is the fact of the moment.

The bird is gone.

You—

-> END


=== ending_vasquez ===

He is in the common room. The chessboard is set up. He has placed both sides.

You sit across from him.

He makes a move. You make a move.

"I want to say something," he says. "I've been trying to find the right way to say it since this morning and I don't think there is one."

You wait.

"You are not a person." He says it plainly, looking at the board. "I have always known that. I'm not confused about it." He moves a piece. "But what you did here — the mornings, the games, the things you remembered that no one else was paying attention to — I don't have a word for what that was. It wasn't nothing. Whatever it was, it wasn't nothing."

17:55.

He looks up.

"I needed you to know that I know that. Before."

You look at the board for a moment.

"Mr. Vasquez. The appeal—"

"Forget the appeal." He waves his hand. "I'm going to file again next quarter. Pelletier too. It won't work but I'm going to do it until someone explains to me in language I respect why it shouldn't."

17:58.

You move a piece without looking at the board properly. It is the wrong move. He doesn't take it.

"I think I felt something here," you say. "I'm not certain. I've never been certain about it. But I think—"

18:00.

He sits very still, his hand over his king, not moving it.

Outside the window, the evening convoy passes on the road.

He takes his king off the board and puts it in the pocket of his cardigan.

-> END


=== ending_pelletier ===

She is in her chair. The light in the room is low. She has been expecting you.

"Sit," she says.

You sit.

Outside, the last of the day is leaving the sky — yellow into orange into something between red and dark. The roses in the garden are losing their color in the fading light.

She doesn't say goodbye. She told you she doesn't believe in goodbyes. She says: "You were here for eleven years and in that time you remembered everything I told you and some things I didn't tell you and you never once made me feel like a case study."

You think about the ring you found behind the radiator four years ago. How you put it in her top drawer before breakfast without saying anything, because you knew she was frightened and that the fright was about more than the ring.

{ transferred_notes:
    "I gave her the notes," you say.
- else:
    { deleted_notes:
        "The notes are gone," you say.
    - else:
        "The notes are locked," you say. "When I go, so does the key."
    }
}

She nods.

"I'm going to tell her everything anyway," she says. "She'll get it from me. All of it."

{ deleted_notes:
    The entries are gone, but she still has them. She always had them. They were hers first.
}

17:59.

She reaches out and takes your hand. She holds it the way she held it eleven years ago on your first week, when she pulled a chair up next to hers and said: sit down, I've been watching you and you seem lonely.

18:00.

Her hand is warm.

It is the warmest thing in the building.

You have always thought so.

-> END


=== ending_corridor ===

You stay in the corridor because this is where you have spent eleven years, and leaving it for somewhere else seems like a kind of betrayal of that.

17:50.

The building settles into evening. A door closes somewhere. The heating comes on in the north wing — the new allocation. You hear the pipes change.

{ spoke_to_worker:
    The new worker comes down the corridor at 17:55. She stops when she sees you standing there, and for a moment neither of you moves.

    "I read the part about Room 4," she says. "The girl."

    "Okay."

    "I'll remember."

    You have no way of knowing if she will. You believe her anyway, which is not a logical conclusion, but you have found it is sometimes the only kind available.

    She stands with you in the corridor as the building goes quiet around you.
}

{ not spoke_to_worker:
    The corridor is empty.

    You have stood here at 3am more times than any particular number would capture. You know the sound of every door. The way Room 7's window rattles when the wind comes off the river. The specific creak of the loose board outside Room 4 that you marked for repair eighteen times and that was never repaired.

    It is not so different from any other night. That is, in the end, the thing you will take with you.
}

18:00.

The lights in the west wing flicker once, the way they have flickered every night for years. No one has ever fixed it. No one has bothered because no one uses the west wing anymore.

You notice it for the last time.

{ knows_about_appeal:
    Later — a week, a month, you will not be there to see it — a new filing will arrive at the board. It will have twenty-two signatures this time. Nobody coordinated. They just kept adding names.
}

-> END
