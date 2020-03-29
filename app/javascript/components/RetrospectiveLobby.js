import React from 'react'
import Cookies from 'js-cookie'
import TextField from '@material-ui/core/TextField'
import Button from '@material-ui/core/Button'
import { post } from 'lib/httpClient'
import consumer from "channels/consumer"
import RetrospectiveBottomBar from './RetrospectiveBottomBar'

const subscribeToRetrospectiveChannels = ({ retrospectiveId }) => {
  const appearanceChannel = consumer.subscriptions.create({ channel: 'AppearanceChannel', retrospective_id: retrospectiveId }, {
    connected() {
      console.log('You are connected to the appearance channel!')
      appearanceChannel.send({ body: 'Hello' })
    },
    disconnected() {
      console.log('You were disconnected from the appearance channel!')
    },
    received(data) {
      if (data.new_participant) {
        console.log('New participant', data.new_participant)
      } else if (data.body) {
        console.log(data.body)
      }
    },
  })

  const orchestratorChannel = consumer.subscriptions.create({ channel: 'OrchestratorChannel', retrospective_id: retrospectiveId }, {
    connected() {
      console.log('You are connected to the orchestrator channel!')
    },
    disconnected() {
      console.log('You were disconnected from the orchestrator channel!')
    },
    received(data) {
      if (data.action === 'next') {
        console.log('Received order to go to next step')
      }
    },
  })
}

const checkLoggedIn = ({ retrospectiveId }) => {
  if (Cookies.get('user_id')) {
    subscribeToRetrospectiveChannels({ retrospectiveId })
    return true
  }

  return false
}

const AvatarPicker = () => {
  return (
    <div>
      You can choose an avatar here:
    </div>
  )
}

const finalizeLogin = ({ retrospectiveId, onLogIn }) => {
  onLogIn(true)
  subscribeToRetrospectiveChannels({ retrospectiveId })
}

const LoginForm = ({ retrospectiveId, onLogIn }) => {
  const [surname, setSurname] = React.useState('')
  const [email, setEmail] = React.useState('')

  const login = () => {
    post({
      url: '/participants',
      payload: {
        retrospective_id: retrospectiveId,
        surname: surname,
        email: email
      }
    })
    .then(profile => onLogIn(profile))
    .catch(error => console.warn(error))
  }

  return (
    <form noValidate autoComplete='off'>
      <div>
        <div>
          You:<br />
          <TextField label='Surname' name='surname' value={surname} onChange={(event) => setSurname(event.target.value)} />
          <TextField label='E-mail' name='email' value={email} onChange={(event) => setEmail(event.target.value)} style={{ marginLeft: '20px' }} />
        </div>
        <Button variant='contained' color='primary' onClick={login}>Join</Button>
      </div>
    </form>
  )
}

const RetrospectiveLobby = ({ id, name, kind, initialProfile }) => {
  const [loggedIn, setloggedIn] = React.useState(checkLoggedIn({ retrospectiveId: id }))
  const [profile, setProfile] = React.useState(initialProfile)
  const finalizeLogin = (profile) => {
    setloggedIn(true)
    setProfile(profile)
    subscribeToRetrospectiveChannels({ retrospectiveId: id })
  }

  return (
    <div>
      <h3>Lobby {name} ({id}) - {kind}</h3>
      {loggedIn && <>
        <div>Logged in as {profile.surname}</div>
        <AvatarPicker />
      </>}
      {!loggedIn && <LoginForm onLogIn={finalizeLogin} retrospectiveId={id} />}
      <RetrospectiveBottomBar organizer={loggedIn && profile.organizer} />
    </div>
  )
}

export default RetrospectiveLobby
