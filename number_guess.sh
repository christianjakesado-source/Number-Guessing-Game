#!/bin/bash

#!/bin/bash

PSQL=(psql -X -q -t -A --username=freecodecamp --dbname=number_guess -v ON_ERROR_STOP=1)

printf 'Enter your username:\n'
IFS= read -r USERNAME || exit 0

USER_ID=$("${PSQL[@]}" -v username="$USERNAME" <<'SQL'
SELECT user_id FROM users WHERE username = :'username';
SQL
) || exit 1

if [[ -z $USER_ID ]]; then
  USER_ID=$("${PSQL[@]}" -v username="$USERNAME" <<'SQL'
INSERT INTO users (username) VALUES (:'username') RETURNING user_id;
SQL
  ) || exit 1

  printf 'Welcome, %s! It looks like this is your first time here.\n' "$USERNAME"
else
  STATS=$("${PSQL[@]}" -v user_id="$USER_ID" <<'SQL'
SELECT COUNT(*), COALESCE(MIN(guesses), 0)
FROM games
WHERE user_id = :'user_id'::INTEGER;
SQL
  ) || exit 1

  IFS='|' read -r GAMES_PLAYED BEST_GAME <<< "$STATS"

  printf 'Welcome back, %s! You have played %s games, and your best game took %s guesses.\n' \
    "$USERNAME" "$GAMES_PLAYED" "$BEST_GAME"
fi

SECRET_NUMBER=$((RANDOM % 1000 + 1))
GUESSES=0

printf 'Guess the secret number between 1 and 1000:\n'

while IFS= read -r GUESS; do
  GUESSES=$((GUESSES + 1))

  if [[ ! $GUESS =~ ^[+-]?[0-9]+$ ]]; then
    printf 'That is not an integer, guess again:\n'
    continue
  fi

  # Handle negative and very large numbers.
  if [[ $GUESS == -* ]]; then
    printf "It's higher than that, guess again:\n"
    continue
  fi

  NUM=$GUESS
  NUM=${NUM#+}

  while [[ ${#NUM} -gt 1 && ${NUM:0:1} == 0 ]]; do
    NUM=${NUM:1}
  done

  if [[ ${#NUM} -gt 4 ]]; then
    printf "It's lower than that, guess again:\n"
    continue
  fi

  VALUE=$((10#$NUM))

  if (( VALUE > SECRET_NUMBER )); then
    printf "It's lower than that, guess again:\n"

  elif (( VALUE < SECRET_NUMBER )); then
    printf "It's higher than that, guess again:\n"

  else
    "${PSQL[@]}" -v user_id="$USER_ID" -v guesses="$GUESSES" > /dev/null <<'SQL'
INSERT INTO games (user_id, guesses)
VALUES (:'user_id'::INTEGER, :'guesses'::INTEGER);
SQL

    printf 'You guessed it in %s tries. The secret number was %s. Nice job!\n' \
      "$GUESSES" "$SECRET_NUMBER"

    exit 0
  fi
done
