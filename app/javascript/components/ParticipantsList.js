import React from 'react'
import { useSelector } from 'react-redux'
import classNames from 'classnames'
import Button from '@material-ui/core/Button'
import './ParticipantsList.scss'

const ParticipantsList = () => {
  const profile = useSelector(state => state.profile)
  const participants = useSelector(state => state.participants)

  const copyUrlToClipboard = () => {
    const toCopy = document.createElement('span')
    toCopy.setAttribute('type', 'hidden')
    toCopy.appendChild(document.createTextNode(window.location.href))
    document.body.appendChild(toCopy);
    const range = document.createRange()
    const selection = window.getSelection()

    range.selectNodeContents(toCopy)
    selection.removeAllRanges()
    selection.addRange(range)
    document.execCommand('copy')
    selection.removeAllRanges()

    toCopy.remove()
    alert('Copied invite URL to clipboard')
  }

  return (
    <div id='participants-list'>
      {participants.map(({ surname, status, organizer, uuid, color }, index) => (
        <div className='participant' key={index}>
          <div className={classNames('participant-status', { 'logged-in': status })} />
          <div
            className={classNames('participant-name', { 'organizer': organizer, 'yourself': profile?.uuid === uuid })}
            style={{ backgroundColor: color }}>
            {surname}
          </div>
        </div>
      ))}
      {profile?.organizer && <Button variant='contained' color='primary' onClick={copyUrlToClipboard}>+</Button>}
    </div>
  )
}

export default ParticipantsList
